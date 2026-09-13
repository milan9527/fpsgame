"""Real Redis heartbeat deadlines; these do not enable live-match admission."""
import json
import os
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
import redis
from fastapi import HTTPException

from app.protocol import BUILD
from app.rooms import RoomDirectory, RoomHeartbeat, RoomTicket, RoomReconnect


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


def issue(directory, body, **changes):
    request = RoomReconnect(**body.model_dump())
    request = request.model_copy(update=changes)
    return directory.allocate_reconnect(str(body.players[0]), "returning_player", 3, request)


def consume_request(ticket):
    return RoomTicket(**dict(BUILD, **{key: ticket[key] for key in
                                      ("ticket", "room_id", "instance_id", "generation", "mode")}))


def test_concurrent_tickets_only_one_can_claim_retained_actor(directory):
    body = room()
    directory.heartbeat(body)
    with ThreadPoolExecutor(max_workers=8) as executor:
        tickets = list(executor.map(lambda _: issue(directory, body), range(8)))
    assert all(0 < ticket["expires_in_ms"] <= 10000 for ticket in tickets)
    def consume(ticket):
        try:
            return directory.consume_reconnect(consume_request(ticket))
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(consume, tickets))
    successes = [result for result in results if isinstance(result, dict)]
    assert len(successes) == 1 and results.count(409) == 7
    assert successes[0]["uid"] == str(body.players[0])
    assert successes[0]["session_version"] == 3
    assert successes[0]["kind"] == "reconnect"
    with pytest.raises(HTTPException):
        issue(directory, body)


@pytest.mark.parametrize("changed", ["uid", "version", "instance", "generation", "mode"])
def test_issue_requires_original_account_and_room_binding(directory, changed):
    body = room()
    directory.heartbeat(body)
    request = RoomReconnect(**body.model_dump())
    uid, version = str(body.players[0]), 3
    if changed == "uid":
        uid = str(uuid.uuid4())
    elif changed == "version":
        version = 4
    elif changed == "mode":
        request.mode = "duo"
    else:
        setattr(request, "instance_id" if changed == "instance" else "generation", uuid.uuid4())
    with pytest.raises(HTTPException) as error:
        directory.allocate_reconnect(uid, "returning_player", version, request)
    assert error.value.status_code == 409


@pytest.mark.parametrize("change", ["removed", "finished", "revoked", "generation", "lease"])
def test_consume_rechecks_current_eligibility(directory, change):
    body = room()
    directory.heartbeat(body)
    ticket = issue(directory, body)
    update = {"revision": 2}
    if change == "removed":
        update["reconnectable"] = {}
    elif change == "finished":
        update.update(phase="finished", reconnectable={})
    elif change == "generation":
        update.update(generation=uuid.uuid4(), reconnectable={})
    elif change == "revoked":
        directory.revoke_reservation(str(body.players[0]), 4)
    else:
        directory.cache.delete(directory.prefix + "room:retained")
    if change in ("removed", "finished", "generation"):
        directory.heartbeat(body.model_copy(update=update))
    with pytest.raises(HTTPException):
        directory.consume_reconnect(consume_request(ticket))


def test_previous_window_ticket_cannot_claim_later_disconnect(directory):
    body = room()
    directory.heartbeat(body)
    first = issue(directory, body)
    unused = issue(directory, body)
    directory.consume_reconnect(consume_request(first))
    with pytest.raises(HTTPException) as error:
        directory.consume_reconnect(consume_request(first))
    assert error.value.status_code == 401
    directory.heartbeat(body.model_copy(update={"revision": 2, "reconnectable": {}}))
    directory.heartbeat(body.model_copy(update={"revision": 3}))
    with pytest.raises(HTTPException):
        directory.consume_reconnect(consume_request(unused))
    second = issue(directory, body)
    assert directory.consume_reconnect(consume_request(second))["epoch"] == 3


def test_lobby_ticket_and_reconnect_ticket_are_not_interchangeable(directory):
    body = room()
    directory.heartbeat(body)
    ticket = issue(directory, body)
    with pytest.raises(HTTPException):
        directory.consume(consume_request(ticket))
    wrong_binding = consume_request(ticket).model_copy(update={"generation": uuid.uuid4()})
    with pytest.raises(HTTPException):
        directory.consume_reconnect(wrong_binding)
    assert directory.consume_reconnect(consume_request(ticket))["uid"] == str(body.players[0])


def test_existing_ticket_cannot_outlive_shortened_retention(directory):
    body = room()
    directory.heartbeat(body)
    ticket = issue(directory, body)
    directory.heartbeat(body.model_copy(update={
        "revision": 2, "reconnectable": {body.players[0]: 1}}))
    time.sleep(1.1)
    with pytest.raises(HTTPException):
        directory.consume_reconnect(consume_request(ticket))
    with pytest.raises(HTTPException):
        issue(directory, body)


def test_connected_player_cannot_request_reconnect_ticket(directory):
    body = room().model_copy(update={"reconnectable": {}})
    directory.heartbeat(body)
    with pytest.raises(HTTPException):
        issue(directory, body)
