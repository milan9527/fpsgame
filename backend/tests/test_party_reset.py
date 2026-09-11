from concurrent.futures import ThreadPoolExecutor
import uuid
import app.main as main
from test_sessions import context
from test_parties import directory
from test_party_matchmaking import form
from test_rooms import heartbeat, consume_body, rejected


def reserve(client, auth):
    response = client.post('/parties/reserve', headers=auth, json=main.BUILD)
    response.raise_for_status()
    return response.json()


def reset(client, auth, party):
    return client.post('/parties/reset', headers=auth,
                       json=dict(main.BUILD, group_id=party['reservation_id']))


def test_reset_pending_keeps_party_and_cancels_tickets(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    first = reserve(client, a)
    second = client.get('/parties/current', headers=b).json()
    assert reset(client, b, first).status_code == 403
    key, _, _ = directory.snapshot(users[0]['id'])
    ttl = main.cache.pttl(key)
    reply = reset(client, a, first)
    assert reply.status_code == 200 and reply.headers['cache-control'] == 'no-store'
    party = reply.json()
    assert party['id'] == first['id'] and party['status'] == 'forming'
    assert all(not member['ready'] for member in party['members'])
    assert 'admission' not in party and 'reservation_id' not in party
    assert 0 < main.cache.pttl(key) <= ttl
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0
    for previous in [first, second]:
        rejected(401, lambda: main.rooms.consume(consume_body(previous['admission']).model_copy(update={'mode': 'duo'})))
    for header in [a, b]:
        client.post('/parties/ready', headers=header, json={'ready': True}).raise_for_status()
    new = reserve(client, a)
    assert new['id'] == first['id'] and new['reservation_id'] != first['reservation_id']
    assert new['admission']['ticket'] != first['admission']['ticket']
    assert reset(client, a, first).status_code == 409
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 2


def test_connected_member_blocks_reset_until_heartbeat_releases(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    room = heartbeat(capacity=2, mode='duo')
    main.rooms.heartbeat(room)
    first = reserve(client, a)
    main.rooms.consume(consume_body(first['admission']).model_copy(update={'mode': 'duo'}))
    room = room.model_copy(update={'revision': 2, 'players': [uuid.UUID(users[0]['id'])]})
    main.rooms.heartbeat(room)
    assert reset(client, a, first).status_code == 409
    assert client.get('/parties/current', headers=b).json()['admission']
    main.rooms.heartbeat(room.model_copy(update={'revision': 3, 'players': []}))
    assert reset(client, a, first).status_code == 200
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0


def test_repeated_reset_does_not_clear_new_readiness(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    first = reserve(client, a)
    with ThreadPoolExecutor(max_workers=3) as executor:
        replies = list(executor.map(lambda _: reset(client, a, first), range(3)))
    assert all(reply.status_code == 200 for reply in replies)
    client.post('/parties/ready', headers=b, json={'ready': True}).raise_for_status()
    repeated = reset(client, a, first).json()
    assert next(member for member in repeated['members'] if member['uid'] == users[1]['id'])['ready']


def test_reset_does_not_touch_newer_session_lease(context, directory, monkeypatch):
    client, users, _ = context
    a, _ = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    first = reserve(client, a)
    key = main.rooms.prefix + 'user_version:' + users[0]['id']
    main.cache.set(key, '1', ex=45)
    assert reset(client, a, first).status_code == 409
    assert main.cache.get(key) == '1'
    assert client.get('/parties/current', headers=a).json()['reservation_id'] == first['reservation_id']
