"""Real Redis heartbeat deadlines; these do not enable live-match admission."""
import json
import os
import time
import uuid

import pytest
import redis
from fastapi import HTTPException

from app.protocol import BUILD
from app.rooms import RoomDirectory, RoomHeartbeat, RoomTicket


@pytest.fixture
def directory():
    cache = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    service = RoomDirectory(cache, "test:reconnect:" + uuid.uuid4().hex + ":")
    yield service
    keys = list(cache.scan_iter(service.prefix + "*"))
    if keys:
        cache.delete(*keys)
    cache.close()


def room():
    uid = uuid.uuid4()
    return RoomHeartbeat(**dict(
        BUILD, room_id="retained", instance_id=uuid.uuid4(),
        generation=uuid.uuid4(), revision=1, host="127.0.0.1", port=27015,
        capacity=2, phase="live", players=[uid], session_versions={uid: 3},
        reconnectable={uid: 30}))


def stored(directory):
    return json.loads(directory.cache.get(directory.prefix + "reconnect:retained"))


def clock_ms(directory):
    seconds, micros = directory.cache.time()
    return seconds * 1000 + micros // 1000


def test_deadline_uses_redis_time_and_cannot_extend(directory):
    body = room()
    uid = str(body.players[0])
    before = clock_ms(directory)
    directory.heartbeat(body)
    deadline = stored(directory)["deadlines"][uid]
    assert before + 30000 <= deadline <= clock_ms(directory) + 30000
    directory.heartbeat(body.model_copy(update={"revision": 2}))
    assert stored(directory)["deadlines"][uid] == deadline
    directory.heartbeat(body.model_copy(update={
        "revision": 3, "reconnectable": {body.players[0]: 1}}))
    shortened = stored(directory)["deadlines"][uid]
    assert shortened < deadline
    directory.heartbeat(body.model_copy(update={"revision": 4}))
    assert stored(directory)["deadlines"][uid] == shortened
    assert 0 < directory.cache.pttl(directory.prefix + "reconnect:retained") <= 12000


def test_omission_removes_eligibility_without_removing_player(directory):
    body = room()
    directory.heartbeat(body)
    directory.heartbeat(body.model_copy(update={"revision": 2, "reconnectable": {}}))
    assert stored(directory)["deadlines"] == {}
    current = json.loads(directory.cache.get(directory.prefix + "room:retained"))
    assert current["players"] == [str(body.players[0])]


def test_stale_heartbeat_cannot_restore_removed_eligibility(directory):
    body = room()
    directory.heartbeat(body)
    directory.heartbeat(body.model_copy(update={"revision": 2, "reconnectable": {}}))
    with pytest.raises(HTTPException) as error:
        directory.heartbeat(body)
    assert error.value.status_code == 409
    assert stored(directory)["deadlines"] == {}


def test_new_round_does_not_inherit_deadlines(directory):
    body = room()
    directory.heartbeat(body)
    generation = uuid.uuid4()
    directory.heartbeat(body.model_copy(update={
        "revision": 2, "generation": generation, "phase": "waiting",
        "players": [], "session_versions": {}, "reconnectable": {}}))
    state = stored(directory)
    assert state["generation"] == str(generation)
    assert state["deadlines"] == {}
    current = json.loads(directory.cache.get(directory.prefix + "room:retained"))
    assert current["players"] == []  # Lua must not turn empty arrays into objects.


def test_player_conflict_leaves_deadlines_unchanged(directory):
    body = room()
    directory.heartbeat(body)
    original = stored(directory)
    intruder = uuid.uuid4()
    directory.cache.set(directory.prefix + "user:" + str(intruder), "other/instance/round")
    changed = body.model_copy(update={
        "revision": 2, "players": [body.players[0], intruder],
        "session_versions": {body.players[0]: 3, intruder: 0},
        "reconnectable": {intruder: 30}})
    with pytest.raises(HTTPException) as error:
        directory.heartbeat(changed)
    assert error.value.status_code == 409
    assert stored(directory) == original


def test_expired_deadline_cannot_be_renewed_by_repeated_declaration(directory):
    body = room()
    body.reconnectable[body.players[0]] = 1
    directory.heartbeat(body)
    uid = str(body.players[0])
    deadline = stored(directory)["deadlines"][uid]
    time.sleep(1.1)
    directory.heartbeat(body.model_copy(update={
        "revision": 2, "reconnectable": {body.players[0]: 30}}))
    assert stored(directory)["deadlines"][uid] == deadline
    assert deadline < clock_ms(directory)


def test_normal_lobby_admission_still_works(directory):
    body = room().model_copy(update={
        "phase": "lobby", "players": [], "session_versions": {}, "reconnectable": {}})
    directory.heartbeat(body)
    uid = str(uuid.uuid4())
    ticket = directory.allocate(uid, "lobby_player")
    consumed = directory.consume(RoomTicket(**dict(
        BUILD, **{key: ticket[key] for key in
                  ("ticket", "room_id", "instance_id", "generation")})))
    assert consumed["uid"] == uid
    assert stored(directory)["deadlines"] == {}
