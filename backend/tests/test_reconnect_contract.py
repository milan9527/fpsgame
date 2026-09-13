"""Heartbeat contract only: no reconnect admission is enabled by these fields."""
import uuid

import pytest
from pydantic import ValidationError

from app.protocol import BUILD
from app.rooms import RoomHeartbeat


def body():
    uid = uuid.uuid4()
    return dict(BUILD, room_id="contract", instance_id=uuid.uuid4(),
                generation=uuid.uuid4(), revision=1, host="127.0.0.1",
                port=27015, capacity=2, phase="live", players=[uid],
                session_versions={uid: 3}, reconnectable={uid: 30})


def test_retained_account_roundtrip():
    data = body()
    heartbeat = RoomHeartbeat(**data)
    restored = RoomHeartbeat.model_validate_json(heartbeat.model_dump_json())
    assert restored.reconnectable == data["reconnectable"]
    assert restored.session_versions == data["session_versions"]


@pytest.mark.parametrize("seconds", [0, -1, 31, True, 1.5, "10", None])
def test_reject_invalid_remaining_time(seconds):
    data = body()
    uid = data["players"][0]
    data["reconnectable"][uid] = seconds
    with pytest.raises(ValidationError):
        RoomHeartbeat(**data)


@pytest.mark.parametrize("phase", ["waiting", "lobby", "finished"])
def test_reject_nonlive_retained_seat(phase):
    data = body()
    data["phase"] = phase
    with pytest.raises(ValidationError):
        RoomHeartbeat(**data)


@pytest.mark.parametrize("missing", ["players", "session_versions"])
def test_reject_unbound_retained_account(missing):
    data = body()
    data[missing] = [] if missing == "players" else {}
    with pytest.raises(ValidationError):
        RoomHeartbeat(**data)


def test_connected_players_do_not_imply_reconnect_permission():
    data = body()
    del data["reconnectable"]
    assert RoomHeartbeat(**data).reconnectable == {}


@pytest.mark.parametrize("seconds", [1, 30])
def test_remaining_time_boundaries(seconds):
    data = body()
    uid = data["players"][0]
    data["reconnectable"][uid] = seconds
    assert RoomHeartbeat(**data).reconnectable[uid] == seconds
