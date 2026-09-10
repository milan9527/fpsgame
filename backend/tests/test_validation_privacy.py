"""Actual HTTP validation must not echo credentials or arbitrary request bodies."""
import json
import os
from pathlib import Path
import uuid
import httpx
import pytest

BASE = os.getenv('TEST_API', 'http://127.0.0.1:8000')

@pytest.mark.parametrize('endpoint', ['/auth/login', '/auth/register'])
@pytest.mark.parametrize('payload', [
    {'username': 'probe_user', 'password': 'secret7'},
    {'username': 'probe_user', 'password': 'private-marker-' * 12},
    {'username': 'probe_user', 'password': {'sensitive-key': 'private-value'}},
    {'username': '../private-user', 'password': 'valid-but-private-password'},
    ['private-body'],
])
def test_invalid_credentials_are_not_echoed(endpoint, payload):
    response = httpx.post(BASE + endpoint, json=payload)
    assert response.status_code == 422
    assert response.headers['cache-control'] == 'no-store'
    body = response.json()
    assert isinstance(body['detail'], str) and body['detail']
    assert body['errors'] and len(body['errors']) <= 20
    assert all(set(issue) == {'field', 'message'} for issue in body['errors'])
    for marker in ['secret7', 'private-marker-', 'sensitive-key', 'private-value', '../private-user', 'valid-but-private-password', 'private-body']:
        assert marker not in response.text
    assert 'input' not in body and 'ctx' not in body


def test_malformed_json_is_not_echoed():
    response = httpx.post(BASE + '/auth/login', content='{"password":"private-json-marker",', headers={'Content-Type': 'application/json'})
    assert response.status_code == 422
    assert response.json()['detail'] == 'Request body must contain valid JSON.'
    assert 'private-json-marker' not in response.text


def test_missing_credentials_have_actionable_guidance():
    response = httpx.post(BASE + '/auth/login', json={})
    assert response.status_code == 422
    assert {item['field'] for item in response.json()['errors']} == {'username', 'password'}


def test_model_validator_context_does_not_echo_body():
    build = json.loads((Path(__file__).resolve().parents[2] / 'client/protocol.json').read_text())
    user = str(uuid.uuid4())
    body = dict(build, room_id='private-heartbeat-marker', instance_id=str(uuid.uuid4()),
                generation=str(uuid.uuid4()), revision=1, host='127.0.0.1', port=27999,
                capacity=16, phase='waiting', players=[user, user])
    response = httpx.post(BASE + '/internal/rooms/heartbeat', json=body,
                          headers={'X-Server-Key': os.environ['SERVER_SECRET']})
    assert response.status_code == 422
    assert response.json()['detail'] == 'Invalid or missing request.'
    assert 'private-heartbeat-marker' not in response.text and user not in response.text
