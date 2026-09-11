"""Four real ENet clients exercise rescue input, interruption and team victory."""
import os
import json
import re
import uuid
import httpx
from pathlib import Path
import subprocess
import time
import argparse
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--parties", action="store_true", help="Reserve two invitation parties and admit A,B,A,B")
options = parser.parse_args()
credentials = [account(f"duo-network-{i}", base="http://127.0.0.1:8001") for i in range(4)]
base = "http://127.0.0.1:8001"
auth = [{"Authorization": "Bearer " + identity["token"]} for identity in credentials]
admissions = {}


def reserve_parties():
    build_response = httpx.get(base + "/protocol")
    build_response.raise_for_status()
    build = build_response.json()
    for header in auth:
        httpx.delete(base + "/parties/current", headers=header).raise_for_status()
    for leader, member in [(0, 2), (1, 3)]:
        party = httpx.post(base + "/parties", headers=auth[leader])
        party.raise_for_status()
        httpx.post(base + "/parties/accept", headers=auth[member],
                   json={"invitation": party.json()["invitation"]}).raise_for_status()
        for _ in range(20):
            result = httpx.post(base + "/parties/reserve", headers=auth[leader],
                                json=dict(build, room_id="room-27032"))
            if result.status_code != 503:
                break
            time.sleep(0.2)
        result.raise_for_status()
        admissions[leader] = result.json()["admission"]
        joined = httpx.get(base + "/parties/current", headers=auth[member])
        joined.raise_for_status()
        admissions[member] = joined.json()["admission"]
        assert admissions[leader]["party_id"] == admissions[member]["party_id"]
        assert admissions[leader]["ticket"] != admissions[member]["ticket"]


def stats(identity, mode):
    response = httpx.get("http://127.0.0.1:8001/profile", params={"mode": mode},
                         headers={"Authorization": "Bearer " + identity["token"]})
    response.raise_for_status()
    return response.json()
before = {identity["user_id"]: {mode: stats(identity, mode) for mode in ["solo", "duo"]}
          for identity in credentials}
env = dict(os.environ, GAME_PORT="27032", GAME_MODE="duo", API_URL="http://127.0.0.1:8001",
           XDG_DATA_HOME=str(ROOT / "artifacts/rescue-network-server-data"))
if options.parties:
    env["TEST_INVITED_PARTIES"] = "1"
env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
    (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
    if line.startswith("DUO_SERVER_SECRET="))
log_prefix = "invited-party-network" if options.parties else "rescue-network"
server_path = ROOT / "artifacts" / f"{log_prefix}-server.log"
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
        if options.parties:
            reserve_parties()
        for i, identity in enumerate(credentials):
            variables = dict(os.environ, TEST_USERNAME=identity["username"], TEST_PASSWORD=identity["password"],
                             TEST_GAME_PORT="27032", TEST_GAME_MODE="duo", API_URL="http://127.0.0.1:8001")
            if options.parties:
                variables.update(TEST_PARTY_TOKEN=identity["token"],
                                 TEST_PARTY_ADMISSION=json.dumps(admissions[i]))
            path = ROOT / "artifacts" / f"{log_prefix}-client-{i}.log"
            output = path.open("w")
            process = subprocess.Popen(
                [str(ROOT / "tools/godot"), "--headless", "--path", "client", "--script",
                 "../tests/rescue_network_client.gd", "--", "--bot-client"],
                cwd=ROOT, env=variables, stdout=output, stderr=subprocess.STDOUT)
            processes.append((process, output, path))
            if options.parties:
                for _ in range(100):
                    if "RESCUE_CLIENT_ADMITTED" in path.read_text():
                        break
                    assert process.poll() is None, str(path)
                    time.sleep(0.05)
                else:
                    raise AssertionError("Invited client did not authenticate: " + str(path))
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
        if options.parties:
            assert "INVITED_INTERLEAVED_TEAMS_PASS" in server_path.read_text()
            by_uid = {row["uid"]: row for row in rows}
            teams = [by_uid[identity["user_id"]]["team"] for identity in credentials]
            assert teams[0] == teams[2] and teams[1] == teams[3] and teams[0] != teams[1]
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
        if options.parties:
            print("INVITED_PARTY_NETWORK_PASS parties=2 interleaved=A_B_A_B tickets=4 authoritative_teams=ok persisted_pairs=ok")
    finally:
        for process, output, _ in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
            output.close()
        server.terminate()
        server.wait(timeout=10)
        if options.parties:
            for header in auth:
                httpx.delete(base + "/parties/current", headers=header).raise_for_status()
