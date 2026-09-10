"""Persistent token/ticket revocation against isolated real PostgreSQL and Redis."""
import concurrent.futures
from datetime import datetime, timedelta, timezone
import uuid
import jwt
import pytest
import redis
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
import app.main as main
from app.migrate import upgrade
from app.models import User
from app.rooms import RoomDirectory

@pytest.fixture
def context(monkeypatch):
    name = 'sessions_test_' + uuid.uuid4().hex
    prefix = 'qa:sessions:' + uuid.uuid4().hex + ':'
    admin = create_engine(main.engine.url, isolation_level='AUTOCOMMIT')
    with admin.connect() as connection:
        connection.execute(text('CREATE DATABASE ' + name))
    engine = create_engine(main.engine.url.set(database=name))
    try:
        with engine.begin() as connection:
            upgrade(connection)
        identities = []
        with Session(engine) as session:
            for index in range(2):
                user = User(id=str(uuid.uuid4()), username='session_user_' + str(index), password=main.passwords.hash('synthetic-session-password'))
                session.add(user)
                identities.append({'username': user.username, 'password': 'synthetic-session-password', 'id': user.id})
            session.commit()
        def isolated_db():
            with Session(engine) as session:
                yield session
        main.app.dependency_overrides[main.db] = isolated_db
        monkeypatch.setattr(main, 'rooms', RoomDirectory(main.cache, prefix=prefix))
        original_limit = main.limit
        monkeypatch.setattr(main, 'limit', lambda key, maximum, seconds: original_limit(prefix + key, maximum, seconds))
        with TestClient(main.app) as client:
            yield client, identities, engine
    finally:
        main.app.dependency_overrides.clear()
        keys = list(main.cache.scan_iter(prefix + '*'))
        if keys:
            main.cache.delete(*keys)
        engine.dispose()
        with admin.connect() as connection:
            connection.execute(text('DROP DATABASE ' + name + ' WITH (FORCE)'))
        admin.dispose()

def login(client, identity):
    response = client.post('/auth/login', json={k: identity[k] for k in ('username','password')})
    assert response.status_code == 200
    return {'Authorization': 'Bearer ' + response.json()['token']}

def test_all_tokens_revoked_and_new_login_works(context):
    client, users, engine = context
    a, b, other = login(client, users[0]), login(client, users[0]), login(client, users[1])
    assert client.post('/auth/logout-all', headers=a).status_code == 200
    assert client.get('/profile', headers=a).status_code == 401
    assert client.get('/profile', headers=b).status_code == 401
    assert client.get('/profile', headers=other).status_code == 200
    assert client.get('/profile', headers=login(client, users[0])).status_code == 200
    with engine.connect() as connection:
        assert connection.scalar(text('SELECT session_version FROM users WHERE id=:id'), {'id':users[0]['id']}) == 1

def test_legacy_token_and_invalid_generation(context):
    client, users, _ = context
    payload = {'sub':users[0]['id'], 'aud':'iron-meridian', 'exp':datetime.now(timezone.utc)+timedelta(minutes=10)}
    legacy = {'Authorization':'Bearer '+jwt.encode(payload,main.JWT_SECRET,algorithm='HS256')}
    assert client.get('/profile',headers=legacy).status_code == 200
    for invalid in [True, '0', -1]:
        header = {'Authorization':'Bearer '+jwt.encode(dict(payload,ver=invalid),main.JWT_SECRET,algorithm='HS256')}
        assert client.get('/profile',headers=header).status_code == 401
    assert client.post('/auth/logout-all',headers=login(client,users[0])).status_code == 200
    assert client.get('/profile',headers=legacy).status_code == 401

def test_ticket_revocation_and_heartbeat_removes_old_session(context):
    client, users, _ = context
    internal = {'X-Server-Key':main.SERVER_SECRET}
    body = dict(main.BUILD,room_id='test-room',instance_id=str(uuid.uuid4()),generation=str(uuid.uuid4()),revision=1,
                host='127.0.0.1',port=27999,capacity=2,phase='lobby',players=[])
    assert client.post('/internal/rooms/heartbeat',json=body,headers=internal).status_code == 200
    auth = login(client,users[0])
    room = client.post('/matchmaking/rooms/join',json=dict(main.BUILD,room_id='test-room'),headers=auth).json()
    legacy = client.post('/matchmaking/join',json=main.BUILD,headers=auth).json()
    assert client.post('/auth/logout-all',headers=auth).status_code == 200
    ticket = dict(main.BUILD,**{k:room[k] for k in ['room_id','instance_id','generation','ticket']})
    assert client.post('/internal/rooms/tickets/consume',json=ticket,headers=internal).status_code == 401
    assert client.post('/internal/tickets/consume',json=dict(main.BUILD,ticket=legacy['ticket']),headers=internal).status_code == 401
    fresh = login(client,users[0])
    assert client.post('/matchmaking/rooms/join',json=dict(main.BUILD,room_id='test-room'),headers=fresh).status_code == 200
    body.update(revision=2,players=[users[0]['id']],session_versions={users[0]['id']:1})
    assert client.post('/internal/rooms/heartbeat',json=body,headers=internal).json()['revoked'] == []
    assert client.post('/auth/logout-all',headers=fresh).status_code == 200
    body['revision'] = 3
    assert client.post('/internal/rooms/heartbeat',json=body,headers=internal).json()['revoked'] == [users[0]['id']]

def test_concurrent_logout_has_one_winner(context):
    client, users, _ = context
    header = login(client,users[0])
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        replies = list(executor.map(lambda _:client.post('/auth/logout-all',headers=header).status_code,range(2)))
    assert sorted(replies) == [200,401]

def test_old_ticket_cancellation_preserves_new_login_reservation(context):
    client, users, _ = context
    internal = {'X-Server-Key': main.SERVER_SECRET}
    body = dict(main.BUILD, room_id='test-room', instance_id=str(uuid.uuid4()),
                generation=str(uuid.uuid4()), revision=1, host='127.0.0.1',
                port=27999, capacity=2, phase='lobby', players=[])
    assert client.post('/internal/rooms/heartbeat', json=body, headers=internal).status_code == 200
    old_auth = login(client, users[0])
    old = client.post('/matchmaking/rooms/join', json=dict(main.BUILD, room_id='test-room'), headers=old_auth).json()
    assert client.post('/auth/logout-all', headers=old_auth).status_code == 200
    fresh_auth = login(client, users[0])
    fresh = client.post('/matchmaking/rooms/join', json=dict(main.BUILD, room_id='test-room'), headers=fresh_auth).json()
    assert client.post('/matchmaking/rooms/cancel', json=dict(main.BUILD, ticket=old['ticket']), headers=fresh_auth).status_code == 200
    ticket = dict(main.BUILD, **{key: fresh[key] for key in ['room_id', 'instance_id', 'generation', 'ticket']})
    response = client.post('/internal/rooms/tickets/consume', json=ticket, headers=internal)
    assert response.status_code == 200
    assert response.json()['session_version'] == 1

def test_database_revocation_survives_cache_cleanup_failure(context, monkeypatch):
    client, users, _ = context
    header = login(client,users[0])
    def fail(*_args):
        raise redis.exceptions.ConnectionError('synthetic cache outage')
    monkeypatch.setattr(main.rooms,'revoke_reservation',fail)
    assert client.post('/auth/logout-all',headers=header).status_code == 503
    assert client.get('/profile',headers=header).status_code == 401
