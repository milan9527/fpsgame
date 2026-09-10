"""Graphical online client opens a tactical map while the authoritative round advances."""
import os
from pathlib import Path
import subprocess
import time
from test_accounts import account

ROOT = Path(__file__).resolve().parent.parent
credentials = account("map-network")
server_env = dict(os.environ, GAME_PORT="27023", API_URL="http://127.0.0.1:8000")
for line in (ROOT / ".env").read_text().splitlines():
    if line.startswith("SERVER_SECRET="):
        server_env["SERVER_SECRET"] = line.split("=", 1)[1]
server_path = ROOT / "artifacts/map-network-server.log"
with server_path.open("w") as output:
    server = subprocess.Popen([str(ROOT / "tools/godot"), "--headless", "--path", "client",
                               "--script", "../tests/map_network_server.gd", "--", "--server"],
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
                   TEST_GAME_PORT="27023", API_URL="http://127.0.0.1:8000")
        client_path = ROOT / "artifacts/map-network-client.log"
        with client_path.open("w") as client_output:
            try:
                result = subprocess.run(["xvfb-run", "-a", str(ROOT / "tools/godot"), "--audio-driver", "Dummy", "--path", "client",
                                         "--script", "../tests/map_network_client.gd", "--", "--bot-client"],
                                        cwd=ROOT, env=env, stdout=client_output, stderr=subprocess.STDOUT, timeout=18)
            except subprocess.TimeoutExpired:
                print(client_path.read_text())
                raise
        text = client_path.read_text()
        print(text)
        assert result.returncode == 0 and "MAP_NETWORK_CLIENT_PASS" in text
        assert not any(error in text for error in ("SCRIPT ERROR", "ObjectDB instances leaked", "Assertion failed"))
        assert "SCRIPT ERROR" not in server_path.read_text(), server_path.read_text()
        print("MAP_NETWORK_PASS authenticated=ok authoritative=ok reliable_world_state=ok")
    finally:
        server.terminate()
        try:
            server.wait(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait()
