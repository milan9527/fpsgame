"""Exercise real PostgreSQL DDL in disposable databases; never reset the live DB."""
import concurrent.futures
import os
import uuid
import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from app.migrate import configuration, upgrade
from app.models import Base


@pytest.fixture
def database():
    url = make_url(os.environ['DATABASE_URL'])
    name = 'migration_test_' + uuid.uuid4().hex
    admin = create_engine(url, isolation_level='AUTOCOMMIT')
    with admin.connect() as connection:
        connection.execute(text('CREATE DATABASE ' + name))
    test_engine = create_engine(url.set(database=name), pool_pre_ping=True)
    try:
        yield test_engine
    finally:
        test_engine.dispose()
        with admin.connect() as connection:
            connection.execute(text('DROP DATABASE ' + name + ' WITH (FORCE)'))
        admin.dispose()


def legacy(connection):
    metadata = ScriptDirectory.from_config(configuration(connection)).get_revision('0001').module.baseline_metadata()
    metadata.create_all(connection)
    user = str(uuid.uuid4())
    match = str(uuid.uuid4())
    connection.execute(text("INSERT INTO users VALUES (:id, 'migration_fixture', 'opaque-test-hash', now(), 1, 1, 3)"), {'id': user})
    connection.execute(text('INSERT INTO matches VALUES (:id, now())'), {'id': match})
    connection.execute(text('INSERT INTO results (match_id, user_id, kills, rank) VALUES (:match, :user, 3, 1)'), {'match': match, 'user': user})


def rows(connection):
    return {table: connection.execute(text(('SELECT id,username,password,created,matches,wins,kills FROM users ORDER BY id' if table == 'users' else 'SELECT * FROM ' + table + ' ORDER BY id'))).all() for table in ('users', 'matches', 'results')}


def test_fresh_and_repeat(database):
    with database.begin() as connection:
        assert upgrade(connection) == '0003'
    with database.begin() as connection:
        assert upgrade(connection) == '0003'
        assert compare_metadata(MigrationContext.configure(connection), Base.metadata) == []
        assert {c['name'] for c in inspect(connection).get_check_constraints('users')} == {'ck_users_stats'}


def test_legacy_data_survives_upgrade_and_downgrade(database):
    with database.begin() as connection:
        legacy(connection)
        before = rows(connection)
    with database.begin() as connection:
        assert upgrade(connection) == '0003'
        assert rows(connection) == before
        assert connection.scalar(text('SELECT session_version FROM users')) == 0
        command.downgrade(configuration(connection), '0001')
        assert rows(connection) == before
    with database.begin() as connection:
        assert upgrade(connection) == '0003'
        assert rows(connection) == before
        with pytest.raises(IntegrityError), connection.begin_nested():
            connection.execute(text('UPDATE users SET wins = matches + 1'))
        with pytest.raises(IntegrityError), connection.begin_nested():
            connection.execute(text('UPDATE results SET rank = 0'))


def test_two_migrators_are_serialized(database):
    with database.begin() as connection:
        legacy(connection)
    def run(_):
        with database.begin() as connection:
            return upgrade(connection)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        assert list(executor.map(run, range(2))) == ['0003', '0003']


def test_drift_is_rejected_without_stamping(database):
    with database.begin() as connection:
        legacy(connection)
        connection.execute(text('ALTER TABLE users ADD COLUMN unexpected text'))
    with pytest.raises(RuntimeError, match='legacy baseline'):
        with database.begin() as connection:
            upgrade(connection)
    with database.connect() as connection:
        assert 'alembic_version' not in inspect(connection).get_table_names()
        assert 'unexpected' in {c['name'] for c in inspect(connection).get_columns('users')}
        assert connection.scalar(text('SELECT count(*) FROM users')) == 1


def test_invalid_existing_data_rolls_back_entire_upgrade(database):
    with database.begin() as connection:
        legacy(connection)
        connection.execute(text('UPDATE users SET wins = 9'))
    with pytest.raises(IntegrityError):
        with database.begin() as connection:
            upgrade(connection)
    with database.connect() as connection:
        assert 'alembic_version' not in inspect(connection).get_table_names()
        assert not inspect(connection).get_check_constraints('users')
        assert connection.scalar(text('SELECT wins FROM users')) == 9


def test_unknown_version_is_not_overwritten(database):
    with database.begin() as connection:
        upgrade(connection)
        connection.execute(text("UPDATE alembic_version SET version_num = 'unknown_future'"))
    with pytest.raises(Exception, match='unknown_future'):
        with database.begin() as connection:
            upgrade(connection)
    with database.connect() as connection:
        assert connection.scalar(text('SELECT version_num FROM alembic_version')) == 'unknown_future'
