"""One-time deployment check: upgrade and prove application rows unchanged.
Run inside the API image with its normal DATABASE_URL after taking a backup.
For this development database only: aggregates all rows, unsuitable for huge DBs.
"""
import json
from sqlalchemy import text
from app.database import engine
from app.migrate import MIGRATION_LOCK, upgrade

TABLES = ('users', 'matches', 'results')


def fingerprint(connection):
    return {table: dict(connection.execute(text(
        'SELECT count(*) AS rows, md5(COALESCE(jsonb_agg(t ORDER BY id)::text, \'[]\')) AS digest FROM ' + table + ' t'
    )).mappings().one()) for table in TABLES}


with engine.begin() as connection:
    connection.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': MIGRATION_LOCK})
    connection.execute(text('LOCK TABLE users, matches, results IN SHARE MODE'))
    before = fingerprint(connection)
    revision = upgrade(connection)
    after = fingerprint(connection)
    if before != after:
        raise RuntimeError('Application data changed during migration; transaction rolled back')
print(json.dumps({'status': 'LIVE_MIGRATION_PRESERVED_DATA', 'revision': revision, 'tables': after}, indent=2))
