"""Exercise real Redis Lua atomicity, plus the authenticated HTTP handlers."""
from concurrent.futures import ThreadPoolExecutor
import os
import uuid

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from app.main import app, cache
from app.protocol import BUILD
from app.rooms import RoomDirectory, RoomHeartbeat, RoomTicket


@pytest.fixture
def directory():
    directory = RoomDirectory(cache, 'test:rooms:' + uuid.uuid4().hex + ':')
    yield directory
    keys = list(cache.scan_iter(directory.prefix + '*'))
    if keys:
        cache.delete(*keys)


def heartbeat(room_id='a', capacity=2, **changes):
    data = dict(BUILD, room_id=room_id, instance_id=uuid.uuid4(), generation=uuid.uuid4(),
                revision=1, host='127.0.0.1', port=27015, capacity=capacity, phase='lobby', players=[])
    data.update(changes)
    return RoomHeartbeat(**data)


def consume_body(result, **changes):
    data = dict(BUILD, **{k: result[k] for k in ('ticket', 'room_id', 'instance_id', 'generation')})
    data.update(changes)
    return RoomTicket(**data)


def rejected(code, operation):
    with pytest.raises(HTTPException) as error:
        operation()
    assert error.value.status_code == code


def test_atomic_capacity_and_user_reservation(directory):
    directory.heartbeat(heartbeat('a'))
    directory.heartbeat(heartbeat('b'))
    def allocate(index):
        try:
            return directory.allocate(str(uuid.uuid4()), 'user_' + str(index))
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=20) as executor:
        results = list(executor.map(allocate, range(20)))
    allocated = [r for r in results if isinstance(r, dict)]
    assert len(allocated) == 4 and results.count(503) == 16
    assert sorted(r['room_id'] for r in allocated) == ['a', 'a', 'b', 'b']


def test_same_user_cannot_reserve_two_rooms(directory):
    directory.heartbeat(heartbeat('a', capacity=16))
    directory.heartbeat(heartbeat('b', capacity=16))
    uid = str(uuid.uuid4())
    def allocate(_):
        try:
            return directory.allocate(uid, 'same_user')
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(allocate, range(8)))
    assert sum(isinstance(r, dict) for r in results) == 1 and results.count(409) == 7


def test_ticket_binding_consumption_and_heartbeat_confirmation(directory):
    room = heartbeat(capacity=1)
    directory.heartbeat(room)
    uid = str(uuid.uuid4())
    result = directory.allocate(uid, 'operator')
    assert 10 <= cache.ttl(directory.prefix + 'room:a') <= 12
    assert 43 <= cache.ttl(directory.prefix + 'user:' + uid) <= 45
    rejected(409, lambda: directory.consume(consume_body(result, room_id='other')))
    rejected(409, lambda: directory.consume(consume_body(result, instance_id=uuid.uuid4())))
    def consume(_):
        try:
            return directory.consume(consume_body(result))
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(consume, range(2)))
    assert sum(isinstance(r, dict) for r in results) == 1 and results.count(401) == 1
    # Consuming a ticket does not free an unconfirmed seat.
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'other'))
    directory.heartbeat(room.model_copy(update={'revision': 2, 'players': [uuid.UUID(uid)]}))
    assert cache.zcard(directory.prefix + 'held:a') == 0
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'other'))
    rejected(409, lambda: directory.allocate(uid, 'operator'))
    directory.heartbeat(room.model_copy(update={'revision': 3, 'players': []}))
    assert directory.allocate(uid, 'operator')['room_id'] == 'a'


def test_phase_generation_and_stale_heartbeat(directory):
    room = heartbeat()
    directory.heartbeat(room)
    result = directory.allocate(str(uuid.uuid4()), 'operator')
    rejected(409, lambda: directory.heartbeat(room))
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={'instance_id': uuid.uuid4(), 'revision': 2})))
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={'capacity': 1, 'revision': 2})))
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={'port': 27016, 'revision': 2})))
    directory.heartbeat(room.model_copy(update={'phase': 'live', 'revision': 2}))
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={'revision': 3})))
    rejected(409, lambda: directory.consume(consume_body(result)))
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'other'))
    directory.heartbeat(room.model_copy(update={'generation': uuid.uuid4(), 'revision': 3}))
    rejected(409, lambda: directory.consume(consume_body(result)))
    assert directory.allocate(str(uuid.uuid4()), 'other')['room_id'] == 'a'


def test_expired_room_and_expired_reservations(directory):
    room = heartbeat(capacity=1)
    directory.heartbeat(room)
    result = directory.allocate(str(uuid.uuid4()), 'operator')
    uid = directory.consume(consume_body(result))['uid']
    # Advance the stored expiry boundary rather than blocking tests for 45s.
    cache.zadd(directory.prefix + 'held:a', {uid: 0})
    cache.delete(directory.prefix + 'user:' + uid)
    second = directory.allocate(str(uuid.uuid4()), 'second')
    cache.delete(directory.prefix + 'room:a')
    rejected(409, lambda: directory.consume(consume_body(second)))
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'third'))
    assert not cache.sismember(directory.prefix + 'directory', 'a')
    directory.heartbeat(heartbeat(capacity=1))
    assert directory.allocate(str(uuid.uuid4()), 'third')['room_id'] == 'a'


def test_heartbeat_cannot_steal_player(directory):
    a, b = heartbeat('a'), heartbeat('b')
    directory.heartbeat(a)
    directory.heartbeat(b)
    uid = str(uuid.uuid4())
    directory.allocate(uid, 'operator', 'a')
    rejected(409, lambda: directory.heartbeat(b.model_copy(update={'revision': 2, 'players': [uuid.UUID(uid)]})))
    assert directory.allocate(str(uuid.uuid4()), 'other', 'b')['room_id'] == 'b'


def test_http_auth_schema_and_compatibility(directory, monkeypatch):
    import app.main as main
    monkeypatch.setattr(main, 'rooms', directory)
    client = TestClient(app)
    room = heartbeat().model_dump(mode='json')
    headers = {'X-Server-Key': os.environ['SERVER_SECRET']}
    assert client.post('/internal/rooms/heartbeat', json=room).status_code == 403
    assert client.post('/internal/rooms/heartbeat', json=dict(room, capacity=True), headers=headers).status_code == 422
    assert client.post('/internal/rooms/heartbeat', json=dict(room, protocol=0), headers=headers).status_code == 422
    assert client.post('/internal/rooms/heartbeat', json=dict(room, content_revision='old'), headers=headers).status_code == 409
    assert client.post('/internal/rooms/heartbeat', json=room, headers=headers).status_code == 200
    assert client.post('/matchmaking/rooms/join', json=BUILD).status_code == 403
    uid = uuid.uuid4()
    with pytest.raises(ValidationError):
        heartbeat(capacity=1, players=[uid, uid])
