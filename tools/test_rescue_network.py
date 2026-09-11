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
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--parties", action="store_true", help="Reserve two invitation parties and admit A,B,A,B")
parser.add_argument("--return-to-party", action="store_true", help="Use the result button to return to each invitation lobby")
parser.add_argument("--revoke-member", action="store_true", help="Revoke a revived teammate and verify their eventual team result")
parser.add_argument("--drop-member", action="store_true", help="Kill a revived client process without graceful leave")
parser.add_argument("--team-pings", action="store_true", help="Publish tactical-map markers and verify per-team delivery")
parser.add_argument("--voice-relay", action="store_true", help="Transmit synthetic encoded audio and verify teammate-only reception")
parser.add_argument("--candidate-dir", type=Path, help="Run server and all clients from a verified packaged candidate")
options = parser.parse_args()
runtime = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
candidate = None
if options.candidate_dir:
    runtime, candidate = candidate_command(options.candidate_dir)
    response = httpx.get("http://127.0.0.1:8001/protocol")
    response.raise_for_status()
    assert response.json() == candidate["manifest"], "Candidate and development API builds differ"
departure_case = options.revoke_member or options.drop_member
if options.voice_relay and departure_case:
    parser.error("--voice-relay is tested separately from departure scenarios")
if options.team_pings and departure_case:
    parser.error("--team-pings is tested separately from departure scenarios")
if options.return_to_party and not options.parties:
    parser.error("--return-to-party requires --parties")
if departure_case and (not options.parties or options.return_to_party or (options.revoke_member and options.drop_member)):
    parser.error("Departure tests require --parties and exactly one departure option")
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
        for index in [leader, member]:
            httpx.post(base + "/parties/ready", headers=auth[index],
                       json={"ready": True}).raise_for_status()
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
if departure_case:
    env["TEST_REVOKE_MEMBER"] = "1"
env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
    (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
    if line.startswith("DUO_SERVER_SECRET="))
log_prefix = "rescue-network"
for enabled, prefix in [(options.parties, "invited-party-network"),
                        (options.return_to_party, "post-match-party"),
                        (options.revoke_member, "revoked-party"),
                        (options.drop_member, "departed-party"),
                        (options.team_pings, "team-pings-network"),
                        (options.voice_relay, "voice-relay-network")]:
    if enabled:
        log_prefix = prefix
if candidate:
    log_prefix = "candidate-" + candidate["commit"][:8] + "-" + log_prefix
server_path = ROOT / "artifacts" / f"{log_prefix}-server.log"
processes = []
with server_path.open("w") as log:
    server = subprocess.Popen(
        runtime + ["--script", str(ROOT / "tests/rescue_network_server.gd"), "--", "--server"],
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
            if options.team_pings:
                variables.update(TEST_TEAM_PINGS="1", TEST_PING_SLOT=str(i))
            if options.voice_relay:
                variables["TEST_VOICE_RELAY"] = "1"
            if departure_case:
                variables["TEST_REVOKE_MEMBER"] = "1"
            if options.parties:
                variables.update(TEST_PARTY_TOKEN=identity["token"],
                                 TEST_PARTY_UID=identity["user_id"],
                                 TEST_RETURN_TO_PARTY="1" if options.return_to_party else "0",
                                 TEST_PARTY_ADMISSION=json.dumps(admissions[i]))
            path = ROOT / "artifacts" / f"{log_prefix}-client-{i}.log"
            output = path.open("w")
            process = subprocess.Popen(
                runtime + ["--script", str(ROOT / "tests/rescue_network_client.gd"), "--", "--bot-client"],
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
        departed_index = -1
        if departure_case:
            for _ in range(500):
                ready = re.search(r"READY_FOR_MEMBER_REVOCATION uid=([0-9a-f-]+)", server_path.read_text())
                if ready:
                    break
                assert server.poll() is None
                time.sleep(0.1)
            else:
                raise AssertionError("Revocation stage not reached")
            departed_index = next(i for i, identity in enumerate(credentials) if identity["user_id"] == ready.group(1))
            partner = 2 if departed_index == 0 else 0
            assert departed_index in [0, 2]
            if options.revoke_member:
                response = httpx.post(base + "/auth/logout-all", headers=auth[departed_index])
                response.raise_for_status()
                assert httpx.get(base + "/profile", headers=auth[departed_index]).status_code == 401
                assert httpx.get(base + "/parties/current", headers=auth[partner]).json() == {}
            else:
                processes[departed_index][0].kill()
                assert httpx.get(base + "/profile", headers=auth[departed_index]).status_code == 200
                assert httpx.get(base + "/parties/current", headers=auth[partner]).json()["id"] == admissions[partner]["party_id"]
        for index, (process, output, path) in enumerate(processes):
            code = process.wait(timeout=75)
            output.close()
            text = path.read_text()
            marker = "REVOKED_MEMBER_CLIENT_PASS" if index == departed_index else "RESCUE_NETWORK_CLIENT_PASS"
            if options.drop_member and index == departed_index:
                assert code < 0, str(path)
            else:
                assert code == 0 and marker in text, str(path)
            if options.return_to_party:
                assert "POST_MATCH_PARTY_RETURN_PASS" in text, str(path)
            if options.team_pings:
                assert "TEAM_PINGS_NETWORK_CLIENT_PASS" in text, str(path)
            if options.voice_relay:
                assert "VOICE_RELAY_CLIENT_PASS" in text, str(path)
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
            if options.revoke_member and identity["user_id"] == credentials[departed_index]["user_id"]:
                response = httpx.post(base + "/auth/login", json={"username": identity["username"], "password": identity["password"]})
                response.raise_for_status()
                identity["token"] = response.json()["token"]
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
        if options.return_to_party:
            print("POST_MATCH_PARTY_RETURN_NETWORK_PASS clients=4 winners_and_losers=ok auth_retained=ok result_rows=4")
        if options.drop_member:
            print("DROPPED_PARTY_NETWORK_PASS abrupt_process_kill=ok peer_timeout=ok party_retained=ok departed_member_rank=1 results=4 stats=ok")
        if options.team_pings:
            print("TEAM_PINGS_NETWORK_PASS clients=4 actual_map_clicks=ok per_team_delivery=ok enemy_isolation=ok")
        if options.voice_relay:
            print("VOICE_RELAY_NETWORK_PASS clients=4 synthetic_packets=ok decoded_samples=ok team_only=ok gameplay_results=ok")
        if options.revoke_member:
            print("REVOKED_PARTY_NETWORK_PASS logout_all=ok party_disband=ok peer_removed=ok surviving_ally_wins=ok departed_member_rank=1 results=4 stats=ok")
        if candidate:
            print("CANDIDATE_NETWORK_PASS commit=" + candidate["commit"] + " archive_sha256=" + candidate["sha256"] + " server=packed clients=4_packed")
    finally:
        for process, output, _ in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
            output.close()
        server.terminate()
        server.wait(timeout=10)
        if options.parties:
            for identity in credentials:
                response = httpx.delete(base + "/parties/current", headers={"Authorization": "Bearer " + identity["token"]})
                assert response.status_code in [200, 401]
