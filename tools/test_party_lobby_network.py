"""Two clients use the player-facing duo lobby against the development service."""
import os
from pathlib import Path
import subprocess
import tempfile
import httpx
from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:8001"


def run():
    identities = [account(f"duo-network-{i}", base=BASE) for i in range(2)]
    auth = [{"Authorization": "Bearer " + identity["token"]} for identity in identities]
    processes = []
    with tempfile.TemporaryDirectory(prefix="party-ui-", dir=ROOT / "artifacts") as private:
        for header in auth:
            httpx.delete(BASE + "/parties/current", headers=header).raise_for_status()
        try:
            for index, identity in enumerate(identities):
                log_path = ROOT / "artifacts" / f"party-lobby-network-{index}.log"
                output = log_path.open("w")
                env = dict(os.environ, TEST_USERNAME=identity["username"],
                           TEST_PASSWORD=identity["password"], API_URL=BASE,
                           XDG_DATA_HOME=str(Path(private) / f"client-{index}"),
                           PARTY_TEST_ROLE="leader" if index == 0 else "member",
                           PARTY_TEST_ALLY=identities[1 - index]["username"],
                           PARTY_TEST_INVITATION_FILE=str(Path(private) / "invitation"))
                process = subprocess.Popen(
                    [str(ROOT / "tools/godot"), "--headless", "--path", "client",
                     "--script", "../tests/party_lobby_network.gd"],
                    cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
                processes.append((process, output, log_path))
            for process, output, path in processes:
                code = process.wait(timeout=65)
                output.close()
                text = path.read_text()
                assert code == 0 and "PARTY_LOBBY_NETWORK_PASS" in text, str(path)
                assert not any(error in text for error in [
                    "SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked"]), str(path)
            print("TWO_CLIENT_PARTY_LOBBY_PASS real_login=ok create_accept_buttons=ok "
                  "member_poll=ok leader_start=ok enet=ok paired_snapshot=ok")
        finally:
            for process, output, _ in processes:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                output.close()
            for header in auth:
                httpx.delete(BASE + "/parties/current", headers=header).raise_for_status()


if __name__ == "__main__":
    run()
