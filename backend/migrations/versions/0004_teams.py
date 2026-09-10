"""Preserve mode and team placement for authoritative match results."""
from alembic import op
import sqlalchemy as sa

revision = '0004'
down_revision = '0003'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('matches', sa.Column('mode', sa.String(8), nullable=False, server_default=sa.text("'solo'")))
    op.create_check_constraint('ck_matches_mode', 'matches', "mode IN ('solo', 'duo')")
    op.add_column('results', sa.Column('team_id', sa.Integer(), nullable=False, server_default=sa.text('0')))
    op.create_check_constraint('ck_results_team', 'results', 'team_id >= 0 AND team_id <= 32')


def downgrade():
    # Old code treats shared team placements as invalid individual placements.
    # Refuse to erase the distinction or silently corrupt historical meaning.
    connection = op.get_bind()
    if connection.scalar(sa.text("SELECT EXISTS (SELECT 1 FROM matches WHERE mode <> 'solo') OR EXISTS (SELECT 1 FROM results WHERE team_id <> 0)")):
        raise RuntimeError('Cannot downgrade team results to the solo-only schema')
    op.drop_constraint('ck_results_team', 'results', type_='check')
    op.drop_column('results', 'team_id')
    op.drop_constraint('ck_matches_mode', 'matches', type_='check')
    op.drop_column('matches', 'mode')
