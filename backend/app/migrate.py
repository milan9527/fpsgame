"""Transactional, serialized migrations, with strict legacy schema adoption."""
from pathlib import Path
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import inspect, text
from .database import engine

MIGRATION_LOCK = 729184103


def configuration(connection):
    config = Config()
    config.set_main_option('script_location', str(Path(__file__).resolve().parent.parent / 'migrations'))
    config.attributes['connection'] = connection
    return config


def upgrade(connection):
    # All callers use one transaction and one lock, including initial adoption.
    connection.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': MIGRATION_LOCK})
    config = configuration(connection)
    tables = set(inspect(connection).get_table_names())
    if 'alembic_version' not in tables and tables:
        baseline = ScriptDirectory.from_config(config).get_revision('0001').module.baseline_metadata()
        differences = compare_metadata(MigrationContext.configure(connection), baseline)
        inspector = inspect(connection)
        primary_keys_match = all(
            set(inspector.get_pk_constraint(table.name)['constrained_columns']) == set(c.name for c in table.primary_key.columns)
            for table in baseline.tables.values() if table.name in tables
        )
        # Alembic does not compare check constraints or primary keys automatically.
        unexpected_checks = any(inspector.get_check_constraints(name) for name in tables)
        if tables != set(baseline.tables) or differences or not primary_keys_match or unexpected_checks:
            raise RuntimeError('Unversioned schema does not match the legacy baseline; no changes applied')
        command.stamp(config, '0001')
    command.upgrade(config, 'head')
    return MigrationContext.configure(connection).get_current_revision()


def main():
    with engine.begin() as connection:
        revision = upgrade(connection)
    print('DATABASE_SCHEMA_READY revision=' + revision)


if __name__ == '__main__':
    main()
