from concurrent.futures import ThreadPoolExecutor
import uuid
import pytest
from fastapi import HTTPException
from sqlalchemy import text
import app.main as main
from app.parties import PartyDirectory
from test_sessions import context, login


@pytest.fixture
def directory():
    directory = PartyDirectory(main.cache, 'qa:parties:' + uuid.uuid4().hex + ':')
    yield directory
    keys = list(main.cache.scan_iter(directory.prefix + '*'))
    if keys:
        main.cache.delete(*keys)


def test_invitation_single_use_and_disband(directory):
    party = directory.create('a', 'Alice')
    assert party['mode'] == 'duo' and 'invite_hash' not in party
    assert 'version' not in party['members'][0]
    joined = directory.accept('b', 'Bob', party['invitation'])
    assert len(joined['members']) == 2 and 'invitation' not in joined
    assert 'invitation' not in directory.get('a')
    with pytest.raises(HTTPException) as error:
        directory.accept('c', 'Carol', party['invitation'])
    assert error.value.status_code == 404
    directory.leave('b')
    assert directory.get('a') == directory.get('b') == {}
    assert directory.leave('b') == {}


def test_concurrent_accept_has_one_winner(directory):
    party = directory.create('a', 'Alice')
    def accept(index):
        try:
            return directory.accept(str(index), 'Guest', party['invitation'])
        except HTTPException as error:
            return error.status_code
    with ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(accept, range(16)))
    assert sum(isinstance(result, dict) for result in results) == 1
    assert sum(result == 404 for result in results) == 15
    assert len(directory.get('a')['members']) == 2


def test_single_membership_and_expired_invitation(directory):
    a = directory.create('a', 'Alice')
    b = directory.create('b', 'Bob')
    with pytest.raises(HTTPException) as error:
        directory.accept('b', 'Bob', a['invitation'])
    assert error.value.status_code == 409
    assert directory.get('b')['id'] == b['id']
    # Expire every lease deterministically; no timing-sensitive sleep.
    for key in directory.cache.scan_iter(directory.prefix + '*'):
        directory.cache.pexpire(key, 0)
    assert directory.get('a') == {}
    with pytest.raises(HTTPException) as error:
        directory.accept('c', 'Carol', a['invitation'])
    assert error.value.status_code == 404
    assert directory.create('a', 'Alice')['id'] != a['id']


def test_revocation_does_not_destroy_new_session_party(directory):
    old = directory.create('a', 'Alice', 0)
    directory.accept('b', 'Bob', old['invitation'], 0)
    directory.revoke('b', 1)
    assert directory.get('a') == {}
    new = directory.create('b', 'Bob', 1)
    directory.revoke('b', 1)
    assert directory.get('b')['id'] == new['id']


def test_authenticated_http_invite_and_logout(context, directory, monkeypatch):
    client, users, _ = context
    monkeypatch.setattr(main, 'parties', directory)
    a, b = login(client, users[0]), login(client, users[1])
    assert client.post('/parties').status_code in [401, 403]
    created = client.post('/parties', headers=a)
    assert created.status_code == 200
    assert created.headers['cache-control'] == 'no-store'
    invitation = created.json()['invitation']
    assert client.get('/parties/current', headers=b).json() == {}
    accepted = client.post('/parties/accept', headers=b, json={'invitation': invitation})
    assert accepted.status_code == 200 and 'invitation' not in accepted.json()
    assert len(client.get('/parties/current', headers=a).json()['members']) == 2
    assert client.post('/auth/logout-all', headers=b).status_code == 200
    assert client.get('/parties/current', headers=b).status_code == 401
    assert client.get('/parties/current', headers=a).json() == {}
    invalid = client.post('/parties/accept', headers=a, json={'invitation': 'private-test-token'})
    assert invalid.status_code == 422 and 'private-test-token' not in invalid.text


def test_committed_revocation_rejects_invite_even_without_cache_cleanup(context, directory, monkeypatch):
    client, users, engine = context
    monkeypatch.setattr(main, 'parties', directory)
    a, b = login(client, users[0]), login(client, users[1])
    invitation = client.post('/parties', headers=a).json()['invitation']
    with engine.begin() as connection:
        connection.execute(text('UPDATE users SET session_version=session_version+1 WHERE id=:id'), {'id': users[0]['id']})
    assert client.post('/parties/accept', headers=b, json={'invitation': invitation}).status_code == 404
    assert directory.get(users[0]['id']) == {}
