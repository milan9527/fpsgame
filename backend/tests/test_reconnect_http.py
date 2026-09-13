"""Authenticated reconnect routes against real PostgreSQL and Redis."""
import os
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import delete, update
from sqlalchemy.orm import Session

import app.main as main
from app.database import engine
from app.models import User
from app.protocol import BUILD
from app.rooms import RoomDirectory


@pytest.fixture
def context(monkeypatch):
    directory = RoomDirectory(main.cache, "test:reconnect-http:" + uuid.uuid4().hex + ":")
    monkeypatch.setattr(main, "rooms", directory)
    uid = str(uuid.uuid4())
    with Session(engine) as session:
        user = User(id=uid, username="re_" + uuid.uuid4().hex[:18],
                    password="unused-test-hash", session_version=0)
        session.add(user)
        session.commit()
        bearer = main.token(user)["token"]
    client = TestClient(main.app)
    room = dict(BUILD, room_id="retained", instance_id=str(uuid.uuid4()),
                generation=str(uuid.uuid4()), revision=1, host="127.0.0.1",
                port=27015, capacity=2, phase="live", mode="solo",
                players=[uid], session_versions={uid: 0}, reconnectable={uid: 30})
    server = {"X-Server-Key": os.environ["SERVER_SECRET"]}
    player = {"Authorization": "Bearer " + bearer}
    request = {key: room[key] for key in
               (*BUILD.keys(), "room_id", "instance_id", "generation", "mode")}
    yield client, directory, uid, room, server, player, request
    client.close()
    keys = list(main.cache.scan_iter(directory.prefix + "*"))
    if keys:
        main.cache.delete(*keys)
    main.cache.delete("room-reconnect:" + uid)
    with Session(engine) as session:
        session.execute(delete(User).where(User.id == uid))
        session.commit()


def prepared(context):
    client, _, _, room, server, player, request = context
    assert client.post("/internal/rooms/heartbeat", json=room, headers=server).status_code == 200
    response = client.post("/matchmaking/rooms/reconnect", json=request, headers=player)
    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    return dict(request, ticket=response.json()["ticket"])


def test_authenticated_issue_and_server_only_single_consumption(context):
    client, _, uid, _, server, player, request = context
    assert client.post("/matchmaking/rooms/reconnect", json=request).status_code == 403
    ticket = prepared(context)
    assert client.post("/internal/rooms/reconnect/consume", json=ticket, headers=player).status_code == 403
    response = client.post("/internal/rooms/reconnect/consume", json=ticket, headers=server)
    assert response.status_code == 200 and response.json()["uid"] == uid
    assert response.headers["cache-control"] == "no-store"
    assert client.post("/internal/rooms/reconnect/consume", json=ticket, headers=server).status_code == 401


def test_reconnect_compatibility_and_rate_limit(context):
    client, _, _, _, server, player, request = context
    ticket = prepared(context)
    assert client.post("/matchmaking/rooms/reconnect", json=dict(request, content_revision="old"), headers=player).status_code == 409
    assert client.post("/internal/rooms/reconnect/consume", json=dict(ticket, content_revision="old"), headers=server).status_code == 409
    for _ in range(9):
        assert client.post("/matchmaking/rooms/reconnect", json=request, headers=player).status_code == 200
    assert client.post("/matchmaking/rooms/reconnect", json=request, headers=player).status_code == 429


def test_database_revocation_rejects_ticket_even_if_redis_lease_remains(context):
    client, _, uid, _, server, player, request = context
    ticket = prepared(context)
    # Simulate the gap after the DB commits logout but before Redis cleanup.
    with Session(engine) as session:
        session.execute(update(User).where(User.id == uid).values(session_version=1))
        session.commit()
    assert client.post("/internal/rooms/reconnect/consume", json=ticket, headers=server).status_code == 401
    assert client.post("/matchmaking/rooms/reconnect", json=request, headers=player).status_code == 401


def test_heartbeat_removes_revoked_reconnect_declarations(context):
    client, directory, uid, room, server, _, _ = context
    prepared(context)
    with Session(engine) as session:
        session.execute(update(User).where(User.id == uid).values(session_version=1))
        session.commit()
    response = client.post("/internal/rooms/heartbeat", json=dict(room, revision=2), headers=server)
    assert response.status_code == 200 and response.json()["revoked"] == [uid]
    import json
    stored = json.loads(main.cache.get(directory.prefix + "room:retained"))
    assert stored["players"] == [] and stored["reconnectable"] == {} and stored["session_versions"] == {}
    retained = json.loads(main.cache.get(directory.prefix + "reconnect:retained"))
    assert retained["deadlines"] == {}
