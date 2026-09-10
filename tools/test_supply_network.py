"""Real authenticated Godot client validates partial quantities and explicit pickup IDs."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parent.parent
credentials = account("supply-network")
server_env = dict(os.environ, GAME_PORT="27018", API_URL="http://127.0.0.1:8000")
for line in (ROOT / ".env").read_text().splitlines():
    if line.startswith("SERVER_SECRET="):
        server_env["SERVER_SECRET"] = line.split("=", 1)[1]
server_path = ROOT / "artifacts/supply-network-server.log"
with server_path.open("w") as output:
    server = subprocess.Popen([str(ROOT / "tools/godot"), "--headless", "--path", "client",
                               "--script", "../tests/supply_network_server.gd", "--", "--server"],
                              cwd=ROOT, env=server_env, stdout=output, stderr=subprocess.STDOUT)
    try:
        for _ in range(250):
            if "SERVER_READY" in server_path.read_text():
                break
            assert server.poll() is None, server_path.read_text()
            time.sleep(0.1)
        else:
            raise AssertionError("Fixture server did not start")
        env = dict(os.environ, TEST_USERNAME=credentials["username"], TEST_PASSWORD=credentials["password"],
                   TEST_GAME_PORT="27018", API_URL="http://127.0.0.1:8000")
        result = subprocess.run([str(ROOT / "tools/godot"), "--headless", "--path", "client",
                                 "--script", "../tests/supply_network_client.gd", "--", "--bot-client"],
                                cwd=ROOT, env=env, capture_output=True, text=True, timeout=18)
        text = result.stdout + result.stderr
        (ROOT / "artifacts/supply-network-client.log").write_text(text)
        print(text)
        assert result.returncode == 0 and "SUPPLY_NETWORK_CLIENT_PASS" in text
        assert not any(error in text for error in ("SCRIPT ERROR", "ObjectDB instances leaked", "Assertion failed"))
        assert "SCRIPT ERROR" not in server_path.read_text(), server_path.read_text()
        print("SUPPLY_NETWORK_PASS authenticated=ok authoritative=ok reliable_world_state=ok")
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
