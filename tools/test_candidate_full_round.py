"""Run a normal-speed candidate match, observing rather than scripting its outcome."""
import argparse
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time
import uuid

import httpx
from candidate_runtime import candidate_command
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:8001"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--mode", choices=["solo", "duo"], required=True)
    options = parser.parse_args()
    runtime, candidate = candidate_command(options.candidate_dir)
    response = httpx.get(BASE + "/protocol")
    response.raise_for_status()
    assert response.json() == candidate["manifest"]
    identity = account(f"vehicle-login-{options.mode}-0", base=BASE)
    headers = {"Authorization": "Bearer " + identity["token"]}
    before = httpx.get(BASE + "/profile", params={"mode": options.mode}, headers=headers).json()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port = str(probe.getsockname()[1])
    output = options.candidate_dir.resolve() / ("natural-round-" + options.mode)
    output.mkdir(exist_ok=True)
    report_path = output / "verification.json"
    report = {"status": "running", "commit": candidate["commit"],
              "archive_sha256": candidate["sha256"], "mode": options.mode, "time_scale": 1}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    processes = []
    streams = []
    started = time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix="iron-natural-round-") as profile:
            env = dict(os.environ, GAME_PORT=port, GAME_MODE=options.mode, API_URL=BASE,
                       XDG_DATA_HOME=profile + "/server")
            env["SERVER_SECRET"] = next(line.split("=", 1)[1] for line in
                (ROOT / "artifacts/duo-dev.env").read_text().splitlines()
                if line.startswith("DUO_SERVER_SECRET="))

            def launch(name, command, environment):
                stream = (output / (name + ".log")).open("w")
                streams.append(stream)
                process = subprocess.Popen(command, env=environment, cwd=ROOT,
                                           stdout=stream, stderr=subprocess.STDOUT)
                processes.append(process)
                return process

            server = launch("server", runtime + ["--script", str(ROOT / "tests/natural_round_server.gd"),
                                                "--", "--server"], env)
            deadline = time.monotonic() + 25
            while "SERVER_READY" not in (output / "server.log").read_text():
                assert server.poll() is None and time.monotonic() < deadline
                time.sleep(0.1)
            client_env = dict(os.environ, TEST_USERNAME=identity["username"],
                              TEST_PASSWORD=identity["password"], TEST_GAME_PORT=port,
                              TEST_GAME_MODE=options.mode, API_URL=BASE,
                              XDG_DATA_HOME=profile + "/client")
            client = launch("client", runtime + ["--", "--bot-client", "--round-client"], client_env)
            deadline = time.monotonic() + 365
            next_progress = time.monotonic() + 30
            while client.poll() is None:
                assert server.poll() is None and time.monotonic() < deadline
                for stream in streams:
                    stream.flush()
                for name in ("server", "client"):
                    text = (output / (name + ".log")).read_text()
                    assert not any(s in text for s in ("ERROR:", "Assertion failed", "ObjectDB instances leaked")), text[-2000:]
                if time.monotonic() >= next_progress:
                    lines = (output / "server.log").read_text().splitlines()
                    print(next((line for line in reversed(lines) if "NATURAL_ROUND_PROGRESS" in line), "Waiting for round"), flush=True)
                    next_progress += 30
                time.sleep(0.2)
            text = (output / "client.log").read_text()
            assert client.returncode == 0 and "FULL_ROUND_CLIENT_PASS" in text, text[-2000:]
            server_text = (output / "server.log").read_text()
            summary = json.loads(re.search(r"NATURAL_ROUND_FINISHED (\{[^\n]+\})", server_text).group(1))
            match_id = str(uuid.UUID(summary["match_id"]))
            query = ("SELECT coalesce(json_agg(json_build_object('uid',r.user_id,'rank',r.rank,"
                     "'kills',r.kills,'mode',m.mode)), '[]'::json) FROM results r "
                     "JOIN matches m ON m.id=r.match_id WHERE m.id='" + match_id + "'")
            for _ in range(60):
                raw = subprocess.check_output(
                    ["docker", "compose", "--env-file", "artifacts/duo-dev.env", "-f", "compose.duo-dev.yaml",
                     "exec", "-T", "postgres", "psql", "-U", "iron", "-d", "iron_duo", "-At",
                     "-v", "ON_ERROR_STOP=1", "-c", query], cwd=ROOT, text=True)
                rows = json.loads(raw)
                if len(rows) == 1:
                    break
                time.sleep(0.2)
            assert len(rows) == 1 and rows[0]["uid"] == identity["user_id"]
            rank = int(re.search(r"FULL_ROUND_CLIENT_PASS rank=(\d+)", text).group(1))
            assert rows[0]["rank"] == rank and rows[0]["mode"] == options.mode
            after = httpx.get(BASE + "/profile", params={"mode": options.mode}, headers=headers).json()
            assert after["matches"] == before["matches"] + 1
            assert after["kills"] == before["kills"] + rows[0]["kills"]
            assert after["wins"] == before["wins"] + int(rank == 1)
            candidate_command(options.candidate_dir)
            report.update(status="passed", summary=summary, rank=rank, result_rows=len(rows),
                          seconds=round(time.monotonic() - started, 2),
                          scope="One automated human client and 15 normal bots; no outcome or circle overrides, no time acceleration")
            print("CANDIDATE_NATURAL_ROUND_PASS " + json.dumps(report), flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        raise
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for stream in streams:
            stream.close()
        if report["status"] == "passed":
            for name in ("server", "client"):
                text = (output / (name + ".log")).read_text()
                if any(s in text for s in ("ERROR:", "Assertion failed", "ObjectDB instances leaked")):
                    report.update(status="failed", failure="Error or leak in final " + name + " log")
                    report_path.write_text(json.dumps(report, indent=2) + "\n")
                    raise RuntimeError(report["failure"])
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
