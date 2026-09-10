"""Private, reusable test credentials for the local integration environment.
Passwords stay in a mode-0600 ignored artifact; runtime tokens are never saved.
"""
import json
import os
from pathlib import Path
import secrets
import uuid
import httpx

ROOT = Path(__file__).resolve().parent.parent
FILE = ROOT / 'artifacts' / 'test-accounts.json'
BASE = 'http://127.0.0.1:8000'


def account(slot, base=BASE):
    records = json.loads(FILE.read_text()) if FILE.exists() else {}
    key = slot if base == BASE else base + '|' + slot
    if key in records:
        credentials = records[key]
        response = httpx.post(base + '/auth/login', json=credentials)
    else:
        credentials = {'username': 'qa_' + uuid.uuid4().hex[:15], 'password': secrets.token_urlsafe(24)}
        response = httpx.post(base + '/auth/register', json=credentials)
        response.raise_for_status()
        records[key] = credentials
        temporary = FILE.with_suffix('.tmp')
        descriptor = os.open(temporary, os.O_CREAT | os.O_TRUNC | os.O_WRONLY, 0o600)
        with os.fdopen(descriptor, 'w') as file:
            json.dump(records, file)
        temporary.replace(FILE)
    response.raise_for_status()
    return dict(response.json(), password=credentials['password'])
