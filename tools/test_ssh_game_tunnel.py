"""Real SSH + published clients, using a disposable loopback-only sshd (sudo required)."""
import json
import getpass
import argparse
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

from test_accounts import account

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["solo", "duo"], default="solo")
    args = parser.parse_args()
    prefix = "ssh" if args.mode == "solo" else "ssh-duo"
    remote_port = 27015 if args.mode == "solo" else 27022
    local_port = 40015 if args.mode == "solo" else 40022
    processes, streams = [], []
    sshd_pid = None
    with tempfile.TemporaryDirectory(prefix="im-ssh-check-") as temp:
        temp = Path(temp)
        try:
            for name in ("host", "identity"):
                subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(temp / name)], check=True)
            with socket.socket() as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            config = temp / "sshd_config"
            config.write_text(f"""Port {port}
ListenAddress 127.0.0.1
HostKey {temp}/host
PidFile {temp}/sshd.pid
AuthorizedKeysFile {temp}/identity.pub
StrictModes no
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM yes
AllowUsers {getpass.getuser()}
AllowTcpForwarding local
PermitOpen 127.0.0.1:8000
""")
            subprocess.run(["sudo", "-n", "/usr/sbin/sshd", "-f", str(config),
                            "-E", str(temp / "sshd.log")], check=True)
            for _ in range(50):
                if (temp / "sshd.pid").exists():
                    break
                time.sleep(.1)
            sshd_pid = int(subprocess.check_output(["sudo", "-n", "cat", str(temp / "sshd.pid")], text=True))
            known = temp / "known_hosts"
            known.write_text(f"[127.0.0.1]:{port} " + (temp / "host.pub").read_text())
            output = (ROOT / f"artifacts/{prefix}-tunnel.log").open("w")
            streams.append(output)
            tunnel = subprocess.Popen([
                sys.executable, str(ROOT / "tools/ssh_game_tunnel.py"), getpass.getuser() + "@127.0.0.1",
                "-i", str(temp / "identity"), "--ssh-port", str(port),
                "--known-hosts", str(known), "--api-port", "18080",
                "--solo-port", "40015", "--duo-port", "40022"],
                stdout=output, stderr=subprocess.STDOUT)
            processes.append(tunnel)
            for _ in range(100):
                if tunnel.poll() is not None:
                    raise RuntimeError((ROOT / f"artifacts/{prefix}-tunnel.log").read_text())
                try:
                    with urllib.request.urlopen("http://127.0.0.1:18080/health", timeout=.3) as response:
                        assert response.status == 200
                    break
                except OSError:
                    time.sleep(.1)
            else:
                raise RuntimeError("SSH API forwarding unavailable")
            clients = []
            for index in range(2):
                credentials = account("network-" + str(index))
                log = (ROOT / f"artifacts/{prefix}-game-client-{index}.log").open("w")
                streams.append(log)
                env = dict(os.environ, TEST_USERNAME=credentials["username"], TEST_PASSWORD=credentials["password"],
                           API_URL="http://127.0.0.1:18080", TEST_ROOM_ID=f"room-{remote_port}",
                           TEST_GAME_PORT=str(local_port), TEST_GAME_MODE=args.mode,
                           XDG_DATA_HOME=str(temp / f"profile-{index}"))
                command = [str(ROOT / "artifacts/IronMeridian-Linux/play.sh"), "--headless", "--max-fps", "60",
                           "--script", str(ROOT / "tests/ssh_tunnel_client.gd"), "--", "--bot-client"]
                process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                processes.append(process)
                clients.append((process, log, index))
            for process, log, index in clients:
                code = process.wait(timeout=60)
                log.flush()
                text = (ROOT / f"artifacts/{prefix}-game-client-{index}.log").read_text()
                print(text[-2000:], flush=True)
                assert code == 0 and "ONLINE_CLIENT_PASS" in text and "SCRIPT ERROR" not in text
            report = dict(status="passed", api_tcp_forward=True, game_clients=2,
                          remote_game_port=remote_port, local_game_port=local_port, mode=args.mode,
                          client_fps_limit=60,
                          transport="Real OpenSSH, temporary loopback SSH daemon, packed Godot clients",
                          scope="SSH forwarding verified on this host; user network not yet verified")
            (ROOT / f"artifacts/{prefix}-tunnel-verification.json").write_text(json.dumps(report, indent=2) + "\n")
            print("SSH_GAME_TUNNEL_PASS api=ok udp=ok two_clients=ok")
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            for stream in streams:
                stream.close()
            if sshd_pid:
                subprocess.run(["sudo", "-n", "kill", str(sshd_pid)], check=False)


if __name__ == "__main__":
    main()
