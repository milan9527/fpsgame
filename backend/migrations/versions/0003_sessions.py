"""Persistent account-wide credential revocation generation."""
from alembic import op
import sqlalchemy as sa
revision = '0003'
down_revision = '0002'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('users', sa.Column('session_version', sa.BigInteger(), nullable=False, server_default=sa.text('0')))

def downgrade():
    op.drop_column('users', 'session_version')
