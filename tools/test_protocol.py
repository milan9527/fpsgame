"""Compatibility gates against the live HTTP API, using existing local QA accounts."""
import concurrent.futures
import json
import subprocess
from pathlib import Path
import httpx
from test_accounts import account

ROOT = Path(__file__).resolve().parent.parent
BASE = 'http://127.0.0.1:8000'
build = json.loads((ROOT / 'client/protocol.json').read_text())
credentials = account('network-0')
auth = {'Authorization': 'Bearer ' + credentials['token']}
secret = next(line.split('=', 1)[1] for line in (ROOT / '.env').read_text().splitlines() if line.startswith('SERVER_SECRET='))
server = {'X-Server-Key': secret}
assert httpx.get(BASE + '/protocol').json() == build
assert httpx.get(BASE + '/health').json()['protocol'] == build['protocol']
for wrong in ({}, dict(build, protocol=build['protocol'] - 1), dict(build, protocol=build['protocol'] + 1), dict(build, content_revision='different-map')):
    reply = httpx.post(BASE + '/matchmaking/join', json=wrong, headers=auth)
    assert reply.status_code == 409, reply.text
    assert 'required' in reply.json()['detail']
    assert httpx.post(BASE + '/internal/build/check', json=wrong, headers=server).status_code == 409
assert httpx.post(BASE + '/matchmaking/join', json=dict(build, protocol=True), headers=auth).status_code == 422
assert httpx.post(BASE + '/internal/build/check', json=build).status_code == 403
assert httpx.post(BASE + '/internal/build/check', json=build, headers=server).json() == build
reply = httpx.post(BASE + '/matchmaking/join', json=build, headers=auth)
assert reply.status_code == 200, reply.text
assert reply.json()['build'] == build
ticket = reply.json()['ticket']
wrong = dict(build, protocol=build['protocol'] + 1, ticket=ticket)
assert httpx.post(BASE + '/internal/tickets/consume', json=wrong, headers=server).status_code == 409
# A rejected server cannot burn a ticket that the compatible server can still use.
def consume(_):
    return httpx.post(BASE + '/internal/tickets/consume', json=dict(build, ticket=ticket), headers=server)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
    replies = list(executor.map(consume, range(2)))
assert sorted(reply.status_code for reply in replies) == [200, 401]
valid = next(reply.json() for reply in replies if reply.status_code == 200)
assert valid['content_revision'] == build['content_revision'] and int(valid['protocol']) == build['protocol']
# A ticket bound to an older release cannot be consumed merely by claiming the new build.
reply = httpx.post(BASE + '/matchmaking/join', json=build, headers=auth)
reply.raise_for_status()
stale = reply.json()['ticket']
script = "import sys,json,hashlib; from app.main import cache; t=json.load(sys.stdin)['ticket']; cache.hset('ticket:'+hashlib.sha256(t.encode()).hexdigest(),'protocol','1')"
subprocess.run(['docker', 'compose', 'exec', '-T', 'api', 'python', '-c', script], input=json.dumps({'ticket': stale}), text=True, cwd=ROOT, check=True)
assert httpx.post(BASE + '/internal/tickets/consume', json=dict(build, ticket=stale), headers=server).status_code == 409
print('PROTOCOL_API_PASS old_client=blocked wrong_map=blocked strict_types=ok server_gate=ok ticket_binding=ok once_only=ok')
