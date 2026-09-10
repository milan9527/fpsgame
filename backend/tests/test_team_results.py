"""Mode-aware results against disposable real PostgreSQL and authenticated HTTP."""
import concurrent.futures
import copy
import uuid
import pytest
from sqlalchemy import select, text
from sqlalchemy.orm import Session
import app.main as main
from app.models import Match, Result, User
from test_sessions import context, login


def payload(users, mode='duo'):
    return {'match_id': str(uuid.uuid4()), 'mode': mode, 'players': [
        {'user_id': u['id'], 'kills': i + 1, 'rank': 1 if mode == 'duo' else i + 1,
         'team_id': 1 if mode == 'duo' else 0} for i, u in enumerate(users)]}


def submit(client, body):
    return client.post('/internal/results', json=body, headers={'X-Server-Key': main.SERVER_SECRET})


def test_shared_victory_and_mode_profile(context):
    client, users, engine = context
    body = payload(users)
    with Session(engine) as session:
        for i in range(2):
            loser = User(id=str(uuid.uuid4()), username='team_loser_' + str(i), password='opaque-hash')
            session.add(loser)
            body['players'].append({'user_id': loser.id, 'kills': 0, 'rank': 2, 'team_id': 2})
        session.commit()
    assert client.post('/internal/results', json=body, headers=login(client, users[0])).status_code == 403
    assert submit(client, body).json() == {'status': 'recorded'}
    assert submit(client, body).json() == {'status': 'already_recorded'}
    solo = payload(users, 'solo')
    assert submit(client, solo).status_code == 200
    for i, user in enumerate(users):
        headers = login(client, user)
        duo_stats = client.get('/profile?mode=duo', headers=headers).json()
        assert (duo_stats['matches'], duo_stats['wins'], duo_stats['kills']) == (1, 1, i + 1)
        solo_stats = client.get('/profile?mode=solo', headers=headers).json()
        assert (solo_stats['matches'], solo_stats['wins']) == (1, int(i == 0))
        assert client.get('/profile', headers=headers).json()['matches'] == 2
    with Session(engine) as session:
        assert session.get(Match, body['match_id']).mode == 'duo'
        rows = list(session.scalars(select(Result).where(Result.match_id == body['match_id'])))
        assert sorted((r.team_id, r.rank) for r in rows) == [(1, 1), (1, 1), (2, 2), (2, 2)]


@pytest.mark.parametrize('failure', ['solo_team', 'solo_duplicate_rank', 'no_team', 'team_rank_mismatch',
                                    'duplicate_team_placement', 'too_many_members', 'bad_mode', 'boolean_team'])
def test_invalid_team_shapes_are_atomic(context, failure):
    client, users, engine = context
    body = payload(users)
    if failure == 'solo_team':
        body['mode'] = 'solo'
    elif failure == 'solo_duplicate_rank':
        body['mode'] = 'solo'
        for player in body['players']:
            player['team_id'] = 0
    elif failure == 'no_team':
        body['players'][0]['team_id'] = 0
    elif failure == 'team_rank_mismatch':
        body['players'][1]['rank'] = 2
    elif failure == 'duplicate_team_placement':
        body['players'][1]['team_id'] = 2
    elif failure == 'too_many_members':
        body['players'].append(dict(body['players'][0], user_id=str(uuid.uuid4())))
    elif failure == 'bad_mode':
        body['mode'] = 'squad'
    else:
        body['players'][0]['team_id'] = True
    assert submit(client, body).status_code == 422
    with engine.connect() as connection:
        assert connection.scalar(text('SELECT count(*) FROM matches')) == 0
        assert connection.scalar(text('SELECT sum(matches) FROM users')) == 0


def test_idempotent_retry_conflict_and_concurrency(context):
    client, users, engine = context
    body = payload(users)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        replies = list(executor.map(lambda _: submit(client, body), range(4)))
    assert all(reply.status_code == 200 for reply in replies)
    assert sum(reply.json()['status'] == 'recorded' for reply in replies) == 1
    for mutate in ['mode', 'kills', 'team', 'players']:
        changed = copy.deepcopy(body)
        if mutate == 'mode':
            changed['mode'] = 'solo'
            for index, player in enumerate(changed['players']):
                player.update(team_id=0, rank=index + 1)
        elif mutate == 'kills':
            changed['players'][0]['kills'] += 1
        elif mutate == 'team':
            for player in changed['players']:
                player['team_id'] = 2
        else:
            changed['players'].pop()
        assert submit(client, changed).status_code == 409
    with engine.connect() as connection:
        assert connection.scalar(text('SELECT count(*) FROM matches')) == 1
        assert connection.scalar(text('SELECT sum(matches) FROM users')) == 2


def test_single_human_bot_partner_and_unknown_user_rollback(context):
    client, users, engine = context
    body = payload(users[:1])
    # A human paired with a bot has only one persistent account result.
    assert submit(client, body).status_code == 200
    invalid = payload(users)
    invalid['players'][1]['user_id'] = str(uuid.uuid4())
    assert submit(client, invalid).status_code == 422
    with engine.connect() as connection:
        assert connection.scalar(text('SELECT count(*) FROM matches')) == 1
        assert connection.scalar(text('SELECT count(*) FROM results')) == 1
        assert connection.scalar(text('SELECT sum(matches) FROM users')) == 1


def test_legacy_result_defaults(context):
    client, users, engine = context
    body = payload(users, 'solo')
    del body['mode']
    for player in body['players']:
        del player['team_id']
    assert submit(client, body).status_code == 200
    with Session(engine) as session:
        assert session.get(Match, body['match_id']).mode == 'solo'
        assert all(row.team_id == 0 for row in session.scalars(select(Result)))
