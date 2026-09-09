"""Runs against the actual HTTP service, PostgreSQL and Redis in compose."""
import concurrent.futures
import os
import uuid
import httpx
import pytest

BASE = os.getenv('TEST_API', 'http://127.0.0.1:8000')
PASSWORD = 'integration-only-password-934!'


@pytest.fixture(scope='module')
def account():
    name = 'test_' + uuid.uuid4().hex[:12]
    response = httpx.post(BASE + '/auth/register', json={'username': name, 'password': PASSWORD})
    assert response.status_code == 201, response.text
    return dict(response.json(), password=PASSWORD)


def auth(account):
    return {'Authorization': 'Bearer ' + account['token']}


def internal():
    return {'X-Server-Key': os.environ['SERVER_SECRET']}


def test_health():
    assert httpx.get(BASE + '/health').json()['status'] == 'ok'


def test_login_and_validation(account):
    response = httpx.post(BASE + '/auth/login', json={'username': account['username'].upper(), 'password': PASSWORD})
    assert response.status_code == 200
    assert httpx.post(BASE + '/auth/login', json={'username': account['username'], 'password': 'incorrect-password'}).status_code == 401
    assert httpx.post(BASE + '/auth/register', json={'username': '../bad', 'password': PASSWORD}).status_code == 422
    assert httpx.post(BASE + '/auth/register', json={'username': account['username'], 'password': PASSWORD}).status_code == 409
    assert httpx.get(BASE + '/profile').status_code in (401, 403)
    assert httpx.get(BASE + '/profile', headers={'Authorization': 'Bearer forged'}).status_code == 401


def test_ticket_atomic_consumption(account):
    response = httpx.post(BASE + '/matchmaking/join', json={}, headers=auth(account))
    assert response.status_code == 200
    ticket = response.json()['ticket']
    assert httpx.post(BASE + '/internal/tickets/consume', json={'ticket': ticket}).status_code == 403
    def consume(_):
        return httpx.post(BASE + '/internal/tickets/consume', json={'ticket': ticket}, headers=internal())
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        replies = list(executor.map(consume, range(2)))
    assert sorted(r.status_code for r in replies) == [200, 401]
    assert next(r for r in replies if r.status_code == 200).json()['uid'] == account['user_id']


def test_results_transaction_idempotency(account):
    before = httpx.get(BASE + '/profile', headers=auth(account)).json()
    payload = {'match_id': str(uuid.uuid4()), 'players': [{'user_id': account['user_id'], 'kills': 4, 'rank': 1}]}
    assert httpx.post(BASE + '/internal/results', json=payload, headers=auth(account)).status_code == 403
    def submit(_):
        return httpx.post(BASE + '/internal/results', json=payload, headers=internal())
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        replies = list(executor.map(submit, range(2)))
    assert all(r.status_code == 200 for r in replies), [r.text for r in replies]
    after = httpx.get(BASE + '/profile', headers=auth(account)).json()
    assert after['matches'] == before['matches'] + 1
    assert after['kills'] == before['kills'] + 4
    assert after['wins'] == before['wins'] + 1
    assert any(r['username'] == account['username'] for r in httpx.get(BASE + '/leaderboard').json())


def test_invalid_result_rolls_back(account):
    match_id = str(uuid.uuid4())
    payload = {'match_id': match_id, 'players': [{'user_id': str(uuid.uuid4()), 'kills': 1, 'rank': 2}]}
    assert httpx.post(BASE + '/internal/results', json=payload, headers=internal()).status_code == 422
    payload['players'][0]['user_id'] = account['user_id']
    assert httpx.post(BASE + '/internal/results', json=payload, headers=internal()).json()['status'] == 'recorded'
    payload['match_id'] = str(uuid.uuid4())
    payload['players'].append(payload['players'][0].copy())
    assert httpx.post(BASE + '/internal/results', json=payload, headers=internal()).status_code == 422
