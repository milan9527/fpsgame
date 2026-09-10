"""Four real ENet clients exercise rescue input, interruption and team victory."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
credentials = [account(f"duo-network-{i}", base="http://127.0.0.1:8001") for i in range(4)]
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
        for path in [server_path] + [entry[2] for entry in processes]:
            assert not any(error in path.read_text() for error in
                           ["SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked",
                            "Snapshot exceeds target"]), str(path)
        print("FOUR_CLIENT_RESCUE_NETWORK_PASS actual_input=ok knock=ok interrupts=2 revive=ok team_victory=ok")
    finally:
        for process, output, _ in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
            output.close()
        server.terminate()
        server.wait(timeout=10)
