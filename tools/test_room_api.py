"""Live HTTP account/room-ticket flow using synthetic server heartbeats."""
import concurrent.futures
import json
from pathlib import Path
import uuid

import httpx
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:8000'
build = json.loads((ROOT / 'client/protocol.json').read_text())
secret = next(line.split('=', 1)[1] for line in (ROOT / '.env').read_text().splitlines()
              if line.startswith('SERVER_SECRET='))
server = {'X-Server-Key': secret}
accounts = [account('room-api-a'), account('room-api-b')]
rooms = [dict(build, room_id='qa-' + uuid.uuid4().hex, instance_id=str(uuid.uuid4()),
              generation=str(uuid.uuid4()), revision=1, host='127.0.0.1', port=27991 + i,
              capacity=1, phase='lobby', players=[]) for i in range(2)]
try:
    for room in rooms:
        assert httpx.post(BASE + '/internal/rooms/heartbeat', json=room).status_code == 403
        response = httpx.post(BASE + '/internal/rooms/heartbeat', json=room, headers=server)
        assert response.status_code == 200, response.text
    tickets = []
    for room, user in zip(rooms, accounts):
        auth = {'Authorization': 'Bearer ' + user['token']}
        response = httpx.post(BASE + '/matchmaking/rooms/join',
                              json=dict(build, room_id=room['room_id']), headers=auth)
        assert response.status_code == 200, response.text
        ticket = response.json()
        assert ticket['port'] == room['port'] and ticket['room_id'] == room['room_id']
        assert httpx.post(BASE + '/matchmaking/rooms/join', json=build, headers=auth).status_code == 409
        cancel_body = {'ticket': ticket['ticket']}
        assert httpx.post(BASE + '/matchmaking/rooms/cancel', json=cancel_body).status_code == 403
        other = next(person for person in accounts if person['user_id'] != user['user_id'])
        assert httpx.post(BASE + '/matchmaking/rooms/cancel', json=cancel_body,
                          headers={'Authorization': 'Bearer ' + other['token']}).status_code == 403
        assert httpx.post(BASE + '/matchmaking/rooms/cancel', json=cancel_body, headers=auth).json()['status'] == 'cancelled'
        assert httpx.post(BASE + '/matchmaking/rooms/cancel', json=cancel_body, headers=auth).json()['status'] == 'inactive'
        response = httpx.post(BASE + '/matchmaking/rooms/join', json=dict(build, room_id=room['room_id']), headers=auth)
        assert response.status_code == 200, response.text
        ticket = response.json()
        tickets.append(dict(build, **{key: ticket[key] for key in
                                      ('ticket', 'room_id', 'instance_id', 'generation')}))
    wrong_room = dict(tickets[0], room_id=rooms[1]['room_id'])
    assert httpx.post(BASE + '/internal/rooms/tickets/consume', json=wrong_room, headers=server).status_code == 409
    def consume(_):
        return httpx.post(BASE + '/internal/rooms/tickets/consume', json=tickets[0], headers=server)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        replies = list(executor.map(consume, range(2)))
    assert sorted(reply.status_code for reply in replies) == [200, 401]
    assert next(reply.json()['uid'] for reply in replies if reply.status_code == 200) == accounts[0]['user_id']
    assert httpx.post(BASE + '/internal/rooms/tickets/consume', json=tickets[1], headers=server).status_code == 200
    print('ROOM_API_PASS authenticated=ok distinct_endpoints=ok user_lease=ok binding=ok once_only=ok cancellation=ok owner=ok reallocate=ok')
finally:
    # Remove reservations and close only the synthetic rooms created by this test.
    for room in rooms:
        response = httpx.post(BASE + '/internal/rooms/heartbeat',
                              json=dict(room, revision=100, generation=str(uuid.uuid4()), phase='finished'),
                              headers=server)
        assert response.status_code == 200, response.text
