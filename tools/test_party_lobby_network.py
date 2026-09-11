"""Two clients use the player-facing duo lobby against the development service."""
import os
import argparse
from pathlib import Path
import subprocess
import tempfile
import httpx
from test_accounts import account
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:8001"


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--requeue", action="store_true")
    parser.add_argument("--candidate-dir", type=Path)
    options = parser.parse_args()
    runtime = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
    candidate = None
    if options.candidate_dir:
        runtime, candidate = candidate_command(options.candidate_dir)
        response = httpx.get(BASE + "/protocol")
        response.raise_for_status()
        assert response.json() == candidate["manifest"], "Candidate and development API builds differ"
    identities = [account(f"duo-network-{i}", base=BASE) for i in range(2)]
    auth = [{"Authorization": "Bearer " + identity["token"]} for identity in identities]
    processes = []
    with tempfile.TemporaryDirectory(prefix="party-ui-", dir=ROOT / "artifacts") as private:
        for header in auth:
            httpx.delete(BASE + "/parties/current", headers=header).raise_for_status()
        try:
            for cycle in range(2 if options.requeue else 1):
                for index, identity in enumerate(identities):
                    log_path = ROOT / "artifacts" / (f"party-requeue-{cycle}-{index}.log" if options.requeue else f"party-lobby-network-{index}.log")
                    if candidate:
                        log_path = log_path.with_name("candidate-" + log_path.name)
                    output = log_path.open("w")
                    env = dict(os.environ, TEST_USERNAME=identity["username"],
                               TEST_PASSWORD=identity["password"], API_URL=BASE,
                               XDG_DATA_HOME=str(Path(private) / f"client-{index}"),
                               PARTY_TEST_REQUEUE=str(cycle),
                               PARTY_TEST_ROLE="leader" if index == 0 else "member",
                               PARTY_TEST_ALLY=identities[1 - index]["username"],
                               PARTY_TEST_INVITATION_FILE=str(Path(private) / "invitation"))
                    process = subprocess.Popen(
                        runtime + ["--script", str(ROOT / "tests/party_lobby_network.gd")],
                        cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT)
                    processes.append((process, output, log_path))
                for process, output, path in processes[-2:]:
                    code = process.wait(timeout=65)
                    output.close()
                    text = path.read_text()
                    assert code == 0 and "PARTY_LOBBY_NETWORK_PASS" in text, str(path)
                    if cycle == 1:
                        assert "PARTY_REQUEUE_CLIENT_PASS" in text, str(path)
                    assert not any(error in text for error in [
                        "SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked"]), str(path)
            print("TWO_CLIENT_PARTY_LOBBY_PASS real_login=ok create_accept_buttons=ok "
                  "member_poll=ok leader_start=ok enet=ok paired_snapshot=ok")
            if options.requeue:
                print("PARTY_REQUEUE_NETWORK_PASS cycles=2 same_party=ok fresh_round=ok ready_again=ok")
            if candidate:
                print("CANDIDATE_PARTY_LOBBY_PASS commit=" + candidate["commit"] + " archive_sha256=" + candidate["sha256"])
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
