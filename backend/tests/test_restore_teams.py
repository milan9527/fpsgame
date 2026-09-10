"""Validate restore inspection against real relational team data."""
import json
import uuid
import sys
from pathlib import Path
import pytest
from sqlalchemy import text
tool_paths = [Path(__file__).resolve().parents[2] / 'tools', Path(__file__).resolve().parents[1] / 'tools']
tool_path = next((path for path in tool_paths if (path / 'restore_drill.py').exists()), None)
if tool_path is None:
    pytest.skip('Restore-tool integration requires the repository tools directory', allow_module_level=True)
sys.path.insert(0, str(tool_path))
from restore_drill import TEAM_SQL, validate_team_state
from test_sessions import context


def test_team_restore_checks_detect_relational_corruption(context):
    _, users, engine = context
    match_id = str(uuid.uuid4())
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO matches(id,mode,created) VALUES (:id,'duo',now())"), {'id': match_id})
        for user in users:
            connection.execute(text("INSERT INTO results(match_id,user_id,kills,rank,team_id) VALUES (:match,:uid,2,1,1)"),
                               {'match': match_id, 'uid': user['id']})
            connection.execute(text("UPDATE users SET matches=1,wins=1,kills=2 WHERE id=:uid"), {'uid': user['id']})
        def inspect():
            value = connection.scalar(text(TEAM_SQL))
            return json.loads(value) if isinstance(value, str) else value
        valid = inspect()
        validate_team_state(valid)
        assert valid['mode_totals']['duo'] == {'matches': 1, 'player_results': 2, 'player_wins': 2, 'kills': 4}
        mutations = [
            ("UPDATE results SET team_id=0 WHERE user_id=:uid", 'invalid_mode_rows'),
            ("UPDATE results SET rank=2 WHERE user_id=:uid", 'invalid_teams'),
            ("UPDATE results SET team_id=2 WHERE user_id=:uid", 'invalid_placements'),
            ("UPDATE users SET kills=3 WHERE id=:uid", 'mismatched_account_totals'),
            ("UPDATE matches SET mode='solo'", 'invalid_mode_rows'),
        ]
        for query, field in mutations:
            savepoint = connection.begin_nested()
            connection.execute(text(query), {'uid': users[0]['id']})
            state = inspect()
            assert state[field] > 0
            with pytest.raises(ValueError, match='team results'):
                validate_team_state(state)
            savepoint.rollback()
        assert inspect() == valid
