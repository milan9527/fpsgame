"""Database-level score invariants and efficient per-player result lookup."""
from alembic import op

revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade():
    op.create_check_constraint('ck_users_stats', 'users', 'matches >= 0 AND wins >= 0 AND kills >= 0 AND wins <= matches')
    op.create_check_constraint('ck_results_values', 'results', 'kills >= 0 AND rank >= 1 AND rank <= 64')
    op.create_index('ix_results_user_id', 'results', ['user_id'])


def downgrade():
    op.drop_index('ix_results_user_id', table_name='results')
    op.drop_constraint('ck_results_values', 'results', type_='check')
    op.drop_constraint('ck_users_stats', 'users', type_='check')
