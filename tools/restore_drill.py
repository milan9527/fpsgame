"""Restore and inspect a backup in an isolated disposable PostgreSQL container."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import time
import uuid
from backup import validate

SQL = """
SELECT json_build_object(
 'schema_revision', (SELECT version_num FROM alembic_version),
 'users', (SELECT count(*) FROM users),
 'matches', (SELECT count(*) FROM matches),
 'results', (SELECT count(*) FROM results),
 'invalid_stats', (SELECT count(*) FROM users WHERE matches<0 OR kills<0 OR wins<0 OR wins>matches),
 'invalid_results', (SELECT count(*) FROM results WHERE kills<0 OR rank<1 OR rank>64),
 'orphan_results', (SELECT count(*) FROM results r LEFT JOIN users u ON u.id=r.user_id LEFT JOIN matches m ON m.id=r.match_id WHERE u.id IS NULL OR m.id IS NULL),
 'duplicate_results', (SELECT count(*) FROM (SELECT match_id,user_id FROM results GROUP BY match_id,user_id HAVING count(*)>1) d),
 'unvalidated_constraints', (SELECT count(*) FROM pg_constraint WHERE connamespace='public'::regnamespace AND NOT convalidated)
);
"""

TEAM_SQL = """
SELECT json_build_object(
 'invalid_mode_rows', (SELECT count(*) FROM results r JOIN matches m ON m.id=r.match_id
   WHERE m.mode NOT IN ('solo','duo') OR (m.mode='solo' AND r.team_id<>0)
      OR (m.mode='duo' AND (r.team_id<1 OR r.team_id>32 OR r.rank>32))),
 'invalid_teams', (SELECT count(*) FROM (
   SELECT r.match_id,r.team_id FROM results r JOIN matches m ON m.id=r.match_id
   WHERE m.mode='duo' GROUP BY r.match_id,r.team_id HAVING count(*)>2 OR min(r.rank)<>max(r.rank)
 ) q),
 'invalid_placements', (SELECT count(*) FROM (
   SELECT r.match_id,r.rank FROM results r JOIN matches m ON m.id=r.match_id
   GROUP BY r.match_id,r.rank,m.mode
   HAVING (m.mode='solo' AND count(*)>1) OR (m.mode='duo' AND count(DISTINCT r.team_id)>1)
 ) q),
 'mismatched_account_totals', (SELECT count(*) FROM users u LEFT JOIN (
   SELECT user_id,count(*) AS matches,sum(kills) AS kills,sum(CASE WHEN rank=1 THEN 1 ELSE 0 END) AS wins
   FROM results GROUP BY user_id
 ) r ON r.user_id=u.id
 WHERE u.matches<>coalesce(r.matches,0) OR u.kills<>coalesce(r.kills,0) OR u.wins<>coalesce(r.wins,0)),
 'mode_totals', (SELECT coalesce(json_object_agg(mode, totals),'{}'::json) FROM (
   SELECT m.mode,json_build_object('matches',count(DISTINCT m.id),'player_results',count(r.id),
     'player_wins',sum(CASE WHEN r.rank=1 THEN 1 ELSE 0 END),'kills',coalesce(sum(r.kills),0)) AS totals
   FROM matches m LEFT JOIN results r ON r.match_id=m.id GROUP BY m.mode
 ) q)
);
"""

def validate_team_state(state):
    if any(state[key] for key in ('invalid_mode_rows', 'invalid_teams', 'invalid_placements', 'mismatched_account_totals')):
        raise ValueError('Restored team results failed mode, placement or account-total checks')


def drill(bundle, report_path):
    os.umask(0o077)
    manifest = validate(bundle)  # Reject corruption before any container is created.
    name = 'iron-restore-drill-' + uuid.uuid4().hex[:12]
    try:
        subprocess.run(['docker', 'run', '-d', '--name', name, '--network', 'none', '--memory', '512m',
                        '--tmpfs', '/var/lib/postgresql/data:rw,size=2147483648',
                        '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_USER=iron',
                        '-e', 'POSTGRES_DB=iron', 'postgres:16-alpine'], stdout=subprocess.DEVNULL, check=True)
        for _ in range(100):
            ready = subprocess.run(['docker', 'exec', name, 'pg_isready', '-U', 'iron', '-d', 'iron'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if ready.returncode == 0:
                break
            time.sleep(.2)
        else:
            raise RuntimeError('Isolated PostgreSQL did not become ready')
        with (bundle / 'postgres.dump').open('rb') as source:
            subprocess.run(['docker', 'exec', '-i', name, 'pg_restore', '-U', 'iron', '-d', 'iron',
                            '--exit-on-error', '--single-transaction', '--no-owner', '--no-privileges'], stdin=source, check=True)
        raw = subprocess.check_output(['docker', 'exec', name, 'psql', '-U', 'iron', '-d', 'iron', '-At', '-v', 'ON_ERROR_STOP=1', '-c', SQL], text=True)
        state = json.loads(raw)
        if state['schema_revision'] not in ['0002', '0003', '0004'] or any(state[key] for key in ['invalid_stats', 'invalid_results', 'orphan_results', 'duplicate_results', 'unvalidated_constraints']):
            raise ValueError('Restored database failed schema or integrity checks')
        if state['schema_revision'] in ['0003', '0004']:
            invalid = subprocess.check_output(['docker', 'exec', name, 'psql', '-U', 'iron', '-d', 'iron', '-At', '-v', 'ON_ERROR_STOP=1', '-c',
                'SELECT count(*) FROM users WHERE session_version IS NULL OR session_version<0'], text=True)
            state['invalid_session_versions'] = int(invalid.strip())
            if state['invalid_session_versions']:
                raise ValueError('Restored session versions failed integrity checks')
        if state['schema_revision'] == '0004':
            raw = subprocess.check_output(['docker', 'exec', name, 'psql', '-U', 'iron', '-d', 'iron', '-At', '-v', 'ON_ERROR_STOP=1', '-c', TEAM_SQL], text=True)
            state['team_results'] = json.loads(raw)
            validate_team_state(state['team_results'])
            mode_probe = "BEGIN; DO $$ BEGIN BEGIN INSERT INTO matches(id,mode,created) VALUES ('restore-mode-probe','invalid',now()); RAISE EXCEPTION 'mode check accepted invalid value'; EXCEPTION WHEN check_violation THEN NULL; END; BEGIN INSERT INTO results(match_id,user_id,kills,rank,team_id) VALUES ('missing-match','missing-user',0,1,-1); RAISE EXCEPTION 'team check accepted invalid value'; EXCEPTION WHEN check_violation THEN NULL; END; END $$; ROLLBACK;"
            subprocess.run(['docker', 'exec', name, 'psql', '-U', 'iron', '-d', 'iron', '-v', 'ON_ERROR_STOP=1', '-c', mode_probe], stdout=subprocess.DEVNULL, check=True)
        # Exercise the restored FK/check constraints and roll back the probe transaction.
        probe = "BEGIN; DO $$ BEGIN BEGIN INSERT INTO results(match_id,user_id,kills,rank) VALUES ('missing-match','missing-user',0,1); RAISE EXCEPTION 'foreign key accepted invalid row'; EXCEPTION WHEN foreign_key_violation THEN NULL; END; END $$; ROLLBACK;"
        subprocess.run(['docker', 'exec', name, 'psql', '-U', 'iron', '-d', 'iron', '-v', 'ON_ERROR_STOP=1', '-c', probe], stdout=subprocess.DEVNULL, check=True)
        report = {'passed': True, 'recorded_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'backup': str(bundle), 'files': manifest['files'], 'restored': state,
                  'queues': {filename: len(json.loads((bundle / filename).read_text())) for filename in ['results.json', 'results-game2.json']},
                  'scope': 'Isolated PostgreSQL restore and structural integrity; queues validated but not replayed; no production replacement.'}
    finally:
        exists = subprocess.run(['docker', 'container', 'inspect', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if exists.returncode == 0:
            subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL, check=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    print('RESTORE_DRILL_PASS ' + str(report_path))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    parser.add_argument('--report', type=Path, default=Path('artifacts/restore-drill.json'))
    args = parser.parse_args()
    drill(args.bundle.resolve(), args.report.resolve())
