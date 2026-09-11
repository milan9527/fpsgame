from concurrent.futures import ThreadPoolExecutor
import hashlib
from sqlalchemy import text
import app.main as main
from test_sessions import context, login
from test_parties import directory
from test_rooms import heartbeat, consume_body, rejected
from app.rooms import PartyMember


def form(client, users, directory, monkeypatch):
    monkeypatch.setattr(main, 'parties', directory)
    a, b = login(client, users[0]), login(client, users[1])
    invitation = client.post('/parties', headers=a).json()['invitation']
    assert client.post('/parties/accept', headers=b, json={'invitation': invitation}).status_code == 200
    for auth in [a, b]:
        assert client.post('/parties/ready', headers=auth, json={'ready': True}).status_code == 200
    return a, b


def test_leader_reserves_once_and_members_receive_only_own_ticket(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    assert client.post('/parties/reserve', headers=b, json=main.BUILD).status_code == 403
    def reserve(_):
        return client.post('/parties/reserve', headers=a, json=main.BUILD)
    with ThreadPoolExecutor(max_workers=4) as executor:
        replies = list(executor.map(reserve, range(4)))
    assert all(reply.status_code == 200 for reply in replies)
    tickets = {reply.json()['admission']['ticket'] for reply in replies}
    assert len(tickets) == 1
    first = replies[0].json()
    second = client.get('/parties/current', headers=b).json()
    assert first['status'] == second['status'] == 'reserved'
    assert first['admission']['ticket'] != second['admission']['ticket']
    assert second['admission']['ticket'] not in replies[0].text
    assert 'reservation' not in first and 'room_prefix' not in first and 'digest' not in replies[0].text
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 2
    for identity, party in zip(users, [first, second]):
        result = main.rooms.consume(consume_body(party['admission']).model_copy(update={'mode': 'duo'}))
        assert result['uid'] == identity['id'] and result['party_id'] == party['id']
    assert 'admission' not in client.get('/parties/current', headers=a).json()


def test_disband_cancels_pending_group(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    first = client.post('/parties/reserve', headers=a, json=main.BUILD).json()['admission']
    second = client.get('/parties/current', headers=b).json()['admission']
    assert client.delete('/parties/current', headers=b).status_code == 200
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0
    for admission in [first, second]:
        rejected(401, lambda: main.rooms.consume(consume_body(admission).model_copy(update={'mode': 'duo'})))


def test_unavailable_room_keeps_party_retryable(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 503
    assert client.get('/parties/current', headers=b).json()['status'] == 'forming'
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 200


def test_changed_party_snapshot_cannot_reserve(context, directory, monkeypatch):
    client, users, _ = context
    form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    key, raw, party = directory.snapshot(users[0]['id'])
    directory.leave(users[1]['id'])
    pair = [PartyMember(uid=user['id'], username=user['username']) for user in users]
    rejected(409, lambda: main.rooms.allocate_party(party['id'], pair, '', key, raw))
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0


def test_revoked_member_blocks_reservation(context, directory, monkeypatch):
    client, users, engine = context
    a, _ = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    with engine.begin() as connection:
        connection.execute(text('UPDATE users SET session_version=session_version+1 WHERE id=:id'), {'id': users[1]['id']})
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 409
    assert directory.get(users[0]['id']) == {}
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0


def test_reserve_disband_race_leaves_no_orphan_capacity(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    with ThreadPoolExecutor(max_workers=2) as executor:
        reserve = executor.submit(client.post, '/parties/reserve', headers=a, json=main.BUILD)
        leave = executor.submit(client.delete, '/parties/current', headers=b)
        assert reserve.result().status_code in [200, 404, 409]
        assert leave.result().status_code == 200
    assert directory.get(users[0]['id']) == directory.get(users[1]['id']) == {}
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0


def test_expired_ticket_not_returned_to_member(context, directory, monkeypatch):
    client, users, _ = context
    a, _ = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    ticket = client.post('/parties/reserve', headers=a, json=main.BUILD).json()['admission']['ticket']
    main.cache.delete(main.rooms.prefix + 'ticket:' + hashlib.sha256(ticket.encode()).hexdigest())
    response = client.get('/parties/current', headers=a)
    assert 'admission' not in response.json() and ticket not in response.text


def test_disband_after_one_admission_preserves_connected_lease(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    first = client.post('/parties/reserve', headers=a, json=main.BUILD).json()['admission']
    second = client.get('/parties/current', headers=b).json()['admission']
    main.rooms.consume(consume_body(first).model_copy(update={'mode': 'duo'}))
    owner_key = main.rooms.prefix + 'user:' + users[0]['id']
    connected_owner = main.cache.get(owner_key)
    assert connected_owner
    assert client.delete('/parties/current', headers=b).status_code == 200
    assert main.cache.get(owner_key) == connected_owner
    assert main.cache.get(main.rooms.prefix + 'user:' + users[1]['id']) is None
    rejected(401, lambda: main.rooms.consume(consume_body(second).model_copy(update={'mode': 'duo'})))


def test_expiring_party_cannot_leave_reservation_past_party_lifetime(context, directory, monkeypatch):
    client, users, _ = context
    a, _ = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    key, _, _ = directory.snapshot(users[0]['id'])
    main.cache.pexpire(key, 40000)
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 409
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0
    assert client.get('/parties/current', headers=a).json()['status'] == 'forming'


def test_readiness_required_and_locked_after_reservation(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    response = client.post('/parties/ready', headers=b, json={'ready': False})
    assert response.status_code == 200 and response.headers['cache-control'] == 'no-store'
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 409
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0
    assert client.post('/parties/ready', headers=b, json={'ready': 'true'}).status_code == 422
    client.post('/parties/ready', headers=b, json={'ready': True}).raise_for_status()
    assert client.post('/parties/reserve', headers=a, json=main.BUILD).status_code == 200
    assert client.post('/parties/ready', headers=b, json={'ready': False}).status_code == 409


def test_readiness_change_invalidates_snapshot(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    key, raw, party = directory.snapshot(users[0]['id'])
    ttl = main.cache.pttl(key)
    client.post('/parties/ready', headers=b, json={'ready': False}).raise_for_status()
    assert 0 < main.cache.pttl(key) <= ttl
    pair = [PartyMember(uid=user['id'], username=user['username']) for user in users]
    rejected(409, lambda: main.rooms.allocate_party(party['id'], pair, '', key, raw))
    assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0


def test_invitation_join_resets_leader_readiness(context, directory, monkeypatch):
    client, users, _ = context
    monkeypatch.setattr(main, 'parties', directory)
    a, b = login(client, users[0]), login(client, users[1])
    assert client.post('/parties/ready', headers=a, json={'ready': True}).status_code == 404
    invitation = client.post('/parties', headers=a).json()['invitation']
    client.post('/parties/ready', headers=a, json={'ready': True}).raise_for_status()
    joined = client.post('/parties/accept', headers=b, json={'invitation': invitation})
    assert joined.status_code == 200
    assert all(member['ready'] is False for member in joined.json()['members'])


def test_cancel_ready_races_start_atomically(context, directory, monkeypatch):
    client, users, _ = context
    a, b = form(client, users, directory, monkeypatch)
    main.rooms.heartbeat(heartbeat(capacity=2, mode='duo'))
    with ThreadPoolExecutor(max_workers=2) as executor:
        start = executor.submit(client.post, '/parties/reserve', headers=a, json=main.BUILD)
        unready = executor.submit(client.post, '/parties/ready', headers=b, json={'ready': False})
        statuses = (start.result().status_code, unready.result().status_code)
    assert statuses in [(200, 409), (409, 200)]
    party = client.get('/parties/current', headers=a).json()
    if statuses[0] == 200:
        assert party['status'] == 'reserved' and all(member['ready'] for member in party['members'])
        assert main.cache.zcard(main.rooms.prefix + 'held:a') == 2
    else:
        assert party['status'] == 'forming' and not all(member['ready'] for member in party['members'])
        assert main.cache.zcard(main.rooms.prefix + 'held:a') == 0
