"""Freeze the original three-table schema, including its legacy index names."""
from alembic import op
import sqlalchemy as sa

revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def baseline_metadata():
    metadata = sa.MetaData()
    sa.Table('users', metadata,
             sa.Column('id', sa.String(36), primary_key=True),
             sa.Column('username', sa.String(24), nullable=False, unique=True, index=True),
             sa.Column('password', sa.String(256), nullable=False),
             sa.Column('created', sa.DateTime(timezone=True), nullable=False),
             sa.Column('matches', sa.Integer, nullable=False),
             sa.Column('wins', sa.Integer, nullable=False),
             sa.Column('kills', sa.Integer, nullable=False))
    sa.Table('matches', metadata,
             sa.Column('id', sa.String(36), primary_key=True),
             sa.Column('created', sa.DateTime(timezone=True), nullable=False))
    sa.Table('results', metadata,
             sa.Column('id', sa.Integer, primary_key=True),
             sa.Column('match_id', sa.String(36), sa.ForeignKey('matches.id'), nullable=False),
             sa.Column('user_id', sa.String(36), sa.ForeignKey('users.id'), nullable=False),
             sa.Column('kills', sa.Integer, nullable=False),
             sa.Column('rank', sa.Integer, nullable=False),
             sa.UniqueConstraint('match_id', 'user_id'))
    return metadata


def upgrade():
    baseline_metadata().create_all(op.get_bind(), checkfirst=False)


def downgrade():
    # Dropping player data is deliberately not a routine application rollback.
    raise RuntimeError('Baseline removal is destructive; restore an approved backup instead')
