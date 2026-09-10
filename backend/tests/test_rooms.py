"""Exercise real Redis Lua atomicity, plus the authenticated HTTP handlers."""
from concurrent.futures import ThreadPoolExecutor
import os
import hashlib
import json
import uuid

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pydantic import ValidationError
from app.main import app, cache
from app.protocol import BUILD
from app.rooms import RoomDirectory, RoomHeartbeat, RoomTicket, RoomJoin


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


def test_cancel_releases_only_owned_unused_reservation(directory):
    directory.heartbeat(heartbeat(capacity=1))
    uid = str(uuid.uuid4())
    result = directory.allocate(uid, 'operator')
    rejected(403, lambda: directory.cancel(str(uuid.uuid4()), result['ticket']))
    assert directory.cancel(uid, result['ticket'])['status'] == 'cancelled'
    assert directory.cancel(uid, result['ticket'])['status'] == 'inactive'
    rejected(401, lambda: directory.consume(consume_body(result)))
    second = directory.allocate(uid, 'operator')
    directory.consume(consume_body(second))
    assert directory.cancel(uid, second['ticket'])['status'] == 'inactive'
    rejected(409, lambda: directory.allocate(uid, 'operator'))
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'other'))


def test_cancel_old_generation_cannot_remove_new_lease(directory):
    room = heartbeat(capacity=1)
    directory.heartbeat(room)
    uid = str(uuid.uuid4())
    old = directory.allocate(uid, 'operator')
    directory.heartbeat(room.model_copy(update={'revision': 2, 'generation': uuid.uuid4()}))
    new = directory.allocate(uid, 'operator')
    assert directory.cancel(uid, old['ticket'])['status'] == 'cancelled'
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'other'))
    assert directory.consume(consume_body(new))['uid'] == uid


def test_cancel_consume_race_preserves_admission_invariant(directory):
    directory.heartbeat(heartbeat(capacity=1))
    uid = str(uuid.uuid4())
    for _ in range(12):
        result = directory.allocate(uid, 'operator')
        def consume():
            try:
                return directory.consume(consume_body(result))
            except HTTPException as error:
                return error.status_code
        with ThreadPoolExecutor(max_workers=2) as executor:
            consumed = executor.submit(consume)
            cancelled = executor.submit(directory.cancel, uid, result['ticket'])
            admission, cancellation = consumed.result(), cancelled.result()
        if isinstance(admission, dict):
            assert cancellation['status'] == 'inactive'
            rejected(409, lambda: directory.allocate(uid, 'operator'))
        else:
            assert admission == 401 and cancellation['status'] == 'cancelled'
            assert not cache.exists(directory.prefix + 'user:' + uid)
        # Reset only this test's lease before the next independent race.
        cache.delete(directory.prefix + 'user:' + uid, directory.prefix + 'held:a')


def test_modes_select_separate_rooms_and_bind_tickets(directory):
    directory.heartbeat(heartbeat('a-duo', mode='duo'))
    directory.heartbeat(heartbeat('b-solo'))
    solo = directory.allocate(str(uuid.uuid4()), 'solo')
    duo = directory.allocate(str(uuid.uuid4()), 'duo', mode='duo')
    assert (solo['room_id'], solo['mode']) == ('b-solo', 'solo')
    assert (duo['room_id'], duo['mode']) == ('a-duo', 'duo')
    rejected(409, lambda: directory.consume(consume_body(duo)))
    assert directory.consume(consume_body(duo, mode='duo'))['mode'] == 'duo'
    rejected(409, lambda: directory.consume(consume_body(solo, mode='duo')))
    assert directory.consume(consume_body(solo))['mode'] == 'solo'


def test_requested_room_cannot_bypass_mode_filter(directory):
    directory.heartbeat(heartbeat('duo', mode='duo'))
    directory.heartbeat(heartbeat('solo'))
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'user', 'duo'))
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'user', 'solo', mode='duo'))
    uid = str(uuid.uuid4())
    directory.allocate(uid, 'user', mode='duo')
    rejected(409, lambda: directory.allocate(uid, 'user', mode='solo'))


def test_mode_change_requires_empty_new_generation(directory):
    room = heartbeat(capacity=2)
    directory.heartbeat(room)
    old = directory.allocate(str(uuid.uuid4()), 'old')
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={'revision': 2, 'mode': 'duo'})))
    new = room.model_copy(update={'revision': 2, 'generation': uuid.uuid4(), 'mode': 'duo'})
    directory.heartbeat(new)
    rejected(409, lambda: directory.consume(consume_body(old)))
    assert directory.allocate(str(uuid.uuid4()), 'new', mode='duo')['mode'] == 'duo'


def test_mode_change_cannot_carry_existing_players(directory):
    uid = uuid.uuid4()
    room = heartbeat(players=[uid])
    directory.heartbeat(room)
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={
        'revision': 2, 'generation': uuid.uuid4(), 'mode': 'duo', 'players': []})))
    directory.heartbeat(room.model_copy(update={'revision': 2, 'players': []}))
    rejected(409, lambda: directory.heartbeat(room.model_copy(update={
        'revision': 3, 'generation': uuid.uuid4(), 'mode': 'duo'})))
    directory.heartbeat(room.model_copy(update={
        'revision': 3, 'generation': uuid.uuid4(), 'mode': 'duo', 'players': []}))


def test_mode_capacity_remains_atomic_under_mixed_requests(directory):
    directory.heartbeat(heartbeat('solo', capacity=4))
    directory.heartbeat(heartbeat('duo', capacity=4, mode='duo'))
    def allocate(index):
        mode = 'duo' if index % 2 else 'solo'
        try:
            result = directory.allocate(str(uuid.uuid4()), 'mode_user', mode=mode)
            assert result['mode'] == mode and result['room_id'] == mode
            return mode
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=20) as executor:
        results = list(executor.map(allocate, range(40)))
    assert results.count('solo') == 4 and results.count('duo') == 4
    assert results.count(503) == 32


def test_legacy_room_and_ticket_are_solo_only(directory):
    room = heartbeat()
    directory.heartbeat(room)
    key = directory.prefix + 'room:a'
    raw = json.loads(cache.get(key))
    raw.pop('mode')
    cache.set(key, json.dumps(raw), ex=12)
    rejected(503, lambda: directory.allocate(str(uuid.uuid4()), 'user', mode='duo'))
    ticket = directory.allocate(str(uuid.uuid4()), 'legacy')
    ticket_key = directory.prefix + 'ticket:' + hashlib.sha256(ticket['ticket'].encode()).hexdigest()
    raw_ticket = json.loads(cache.get(ticket_key))
    raw_ticket.pop('mode')
    cache.set(ticket_key, json.dumps(raw_ticket), ex=45)
    rejected(409, lambda: directory.consume(consume_body(ticket, mode='duo')))
    assert directory.consume(consume_body(ticket))['mode'] == 'solo'


def test_mode_schema_and_duo_capacity_are_strict(directory, monkeypatch):
    import app.main as main
    monkeypatch.setattr(main, 'rooms', directory)
    for invalid in ['squad', '', True, None, 2]:
        with pytest.raises(ValidationError):
            RoomJoin(**dict(BUILD, mode=invalid))
    for capacity in [1, 3, 15]:
        with pytest.raises(ValidationError):
            heartbeat(mode='duo', capacity=capacity)
    headers = {'X-Server-Key': os.environ['SERVER_SECRET']}
    with TestClient(app) as client:
        body = heartbeat(mode='duo').model_dump(mode='json')
        assert client.post('/internal/rooms/heartbeat', json=body, headers=headers).status_code == 200
        invalid = dict(body, mode='squad')
        response = client.post('/internal/rooms/heartbeat', json=invalid, headers=headers)
        assert response.status_code == 422 and response.json()['errors'][0]['field'] == 'mode'
