"""Four real clients verify isolated duo admission and authoritative team snapshots."""
import os
from pathlib import Path
import subprocess
import re
import time
from test_accounts import account

root = Path(__file__).resolve().parent.parent
processes = []
peer_ids = []
try:
    credentials = [account(f"duo-network-{i}", base="http://127.0.0.1:8001") for i in range(4)]
    for i, credential in enumerate(credentials):
        path = root / "artifacts" / f"duo-network-client-{i}.log"
        log = path.open("w")
        env = dict(os.environ, API_URL="http://127.0.0.1:8001",
                   TEST_USERNAME=credential["username"], TEST_PASSWORD=credential["password"])
        process = subprocess.Popen(
            [str(root / "tools/godot"), "--headless", "--path", str(root / "client"),
             "--script", str(root / "tests/duo_network_client.gd")],
            env=env, stdout=log, stderr=subprocess.STDOUT)
        processes.append((process, log, path))
    for process, log, path in processes:
        code = process.wait(timeout=50)
        log.close()
        text = path.read_text()
        assert code == 0 and "DUO_NETWORK_CLIENT_PASS" in text, str(path)
        assert not any(error in text for error in
                       ("SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked")), str(path)
        print(next(line for line in text.splitlines() if "DUO_NETWORK_CLIENT_PASS" in line))
        peer_ids.append(re.search(r"DUO_NETWORK_CLIENT_PASS peer=(\d+)", text).group(1))
finally:
    for process, log, _ in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        log.close()
for _ in range(50):
    server = subprocess.check_output(
        ["docker", "compose", "--env-file", "artifacts/duo-dev.env",
         "-f", "compose.duo-dev.yaml", "logs", "--no-color", "--since", "2m", "game"],
        cwd=root, text=True)
    if all("PEER_DISCONNECTED peer=" + peer in server for peer in peer_ids) and "ROOM_IDLE " in server:
        break
    time.sleep(0.2)
else:
    raise AssertionError("Duo server did not release disconnected clients")
assert "SCRIPT ERROR" not in server and "Assertion failed" not in server
(root / "artifacts/duo-network-server.log").write_text(server)
print("FOUR_CLIENT_DUO_ADMISSION_PASS")
