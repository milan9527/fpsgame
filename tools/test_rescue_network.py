"""Four real ENet clients exercise rescue input, interruption and team victory."""
import os
import json
import re
import uuid
import httpx
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
credentials = [account(f"duo-network-{i}", base="http://127.0.0.1:8001") for i in range(4)]
def stats(identity, mode):
    response = httpx.get("http://127.0.0.1:8001/profile", params={"mode": mode},
                         headers={"Authorization": "Bearer " + identity["token"]})
    response.raise_for_status()
    return response.json()
before = {identity["user_id"]: {mode: stats(identity, mode) for mode in ["solo", "duo"]}
          for identity in credentials}
env = dict(os.environ, GAME_PORT="27032", GAME_MODE="duo", API_URL="http://127.0.0.1:8001",
           XDG_DATA_HOME=str(ROOT / "artifacts/rescue-network-server-data"))
env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
    (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
    if line.startswith("DUO_SERVER_SECRET="))
server_path = ROOT / "artifacts/rescue-network-server.log"
processes = []
with server_path.open("w") as log:
    server = subprocess.Popen(
        [str(ROOT / "tools/godot"), "--headless", "--path", "client", "--script",
         "../tests/rescue_network_server.gd", "--", "--server"],
        cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(250):
            if "SERVER_READY" in server_path.read_text():
                break
            assert server.poll() is None, str(server_path)
            time.sleep(0.1)
        else:
            raise AssertionError("Rescue fixture readiness timeout")
        for i, identity in enumerate(credentials):
            variables = dict(os.environ, TEST_USERNAME=identity["username"], TEST_PASSWORD=identity["password"],
                             TEST_GAME_PORT="27032", TEST_GAME_MODE="duo", API_URL="http://127.0.0.1:8001")
            path = ROOT / "artifacts" / f"rescue-network-client-{i}.log"
            output = path.open("w")
            process = subprocess.Popen(
                [str(ROOT / "tools/godot"), "--headless", "--path", "client", "--script",
                 "../tests/rescue_network_client.gd", "--", "--bot-client"],
                cwd=ROOT, env=variables, stdout=output, stderr=subprocess.STDOUT)
            processes.append((process, output, path))
        for process, output, path in processes:
            code = process.wait(timeout=55)
            output.close()
            text = path.read_text()
            assert code == 0 and "RESCUE_NETWORK_CLIENT_PASS" in text, str(path)
        assert "RESCUE_NETWORK_SERVER_PASS" in server_path.read_text(), str(server_path)
        match_id = str(uuid.UUID(re.search(r"RESCUE_NETWORK_SERVER_PASS match_id=([0-9a-f-]+)",
                                          server_path.read_text()).group(1)))
        query = ("SELECT coalesce(json_agg(json_build_object('uid',r.user_id,'team',r.team_id,"
                 "'rank',r.rank,'kills',r.kills,'mode',m.mode)), '[]'::json) "
                 "FROM results r JOIN matches m ON m.id=r.match_id WHERE m.id='" + match_id + "'")
        for _ in range(100):
            raw = subprocess.check_output(
                ["docker", "compose", "--env-file", "artifacts/duo-dev.env", "-f", "compose.duo-dev.yaml",
                 "exec", "-T", "postgres", "psql", "-U", "iron", "-d", "iron_duo", "-At",
                 "-v", "ON_ERROR_STOP=1", "-c", query], cwd=ROOT, text=True)
            rows = json.loads(raw)
            if len(rows) == 4 and "RESULT_PERSISTED" in server_path.read_text():
                break
            time.sleep(0.2)
        else:
            raise AssertionError("Duo results did not persist after serialized outbox reload")
        assert {row["uid"] for row in rows} == {identity["user_id"] for identity in credentials}
        assert sorted((row["team"], row["rank"]) for row in rows) == [(1, 1), (1, 1), (2, 2), (2, 2)]
        assert sum(row["kills"] for row in rows) == 2
        assert all(row["mode"] == "duo" for row in rows)
        for identity in credentials:
            row = next(row for row in rows if row["uid"] == identity["user_id"])
            previous = before[identity["user_id"]]["duo"]
            after = stats(identity, "duo")
            assert after["matches"] == previous["matches"] + 1
            assert after["wins"] == previous["wins"] + int(row["rank"] == 1)
            assert after["kills"] == previous["kills"] + row["kills"]
            assert stats(identity, "solo") == before[identity["user_id"]]["solo"]
        for path in [server_path] + [entry[2] for entry in processes]:
            assert not any(error in path.read_text() for error in
                           ["SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked",
                            "Snapshot exceeds target"]), str(path)
        print("FOUR_CLIENT_RESCUE_NETWORK_PASS actual_input=ok knock=ok interrupts=2 revive=ok team_victory=ok database=4_results outbox_reload=ok mode_stats=ok")
    finally:
        for process, output, _ in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
            output.close()
        server.terminate()
        server.wait(timeout=10)
