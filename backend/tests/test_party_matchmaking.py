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
