"""Verify real accounts from a separate Docker network namespace over SSH."""
import argparse
import getpass
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "iron-meridian-ssh-test-client:0.38"


def request(path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request("http://127.0.0.1:18080" + path,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


def client_runner():
    config = json.loads(Path("/private/config.json").read_text())
    processes, streams = [], []
    try:
        # The production API is intentionally unavailable on the host's bridge address.
        try:
            urllib.request.urlopen("http://" + config["host"] + ":8000/health", timeout=1)
        except OSError:
            direct_api_blocked = True
        else:
            raise AssertionError("Expected loopback-only API, but direct bridge access succeeded")
        log = Path("/evidence/tunnel.log").open("w")
        streams.append(log)
        tunnel = subprocess.Popen([
            "python3", "/source/tools/ssh_game_tunnel.py", config["user"] + "@" + config["host"],
            "-i", "/private/identity", "--known-hosts", "/private/known_hosts",
            "--ssh-port", str(config["port"]), "--api-port", "18080"],
            stdout=log, stderr=subprocess.STDOUT)
        processes.append(tunnel)
        for _ in range(100):
            assert tunnel.poll() is None, "SSH tunnel exited"
            try:
                if request("/health")[0] == 200:
                    break
            except OSError:
                pass
            time.sleep(.1)
        else:
            raise AssertionError("Forwarded API unavailable")
        assert request("/profile")[0] == 403
        accounts = []
        for credentials in config["accounts"]:
            status, login = request("/auth/login", credentials)
            assert status == 200 and login["username"] == credentials["username"]
            status, profile = request("/profile", token=login["token"])
            assert status == 200 and profile["username"] == credentials["username"]
            invalid = dict(credentials, password=credentials["password"] + "-invalid")
            assert request("/auth/login", invalid)[0] == 401
            accounts.append({"username": credentials["username"], "login_http": 200,
                             "profile_http": 200, "wrong_password_http": 401})
        clients = []
        for index, credentials in enumerate(config["accounts"]):
            path = Path(f"/evidence/client-{index}.log")
            output = path.open("w")
            streams.append(output)
            env = dict(os.environ, TEST_USERNAME=credentials["username"], TEST_PASSWORD=credentials["password"],
                       API_URL="http://127.0.0.1:18080", TEST_ROOM_ID="room-27015",
                       XDG_DATA_HOME=f"/tmp/profile-{index}")
            process = subprocess.Popen([
                "/app/IronMeridian", "--headless", "--main-pack", "/app/IronMeridian.pck",
                "--max-fps", "60", "--script", "/source/tests/ssh_tunnel_client.gd", "--", "--bot-client"],
                env=env, stdout=output, stderr=subprocess.STDOUT)
            processes.append(process)
            clients.append((process, output, path))
        for process, output, path in clients:
            code = process.wait(timeout=60)
            output.flush()
            text = path.read_text()
            assert code == 0 and "ONLINE_CLIENT_PASS" in text and "SCRIPT ERROR" not in text, text[-2000:]
        report = {"status": "passed", "accounts": accounts, "game_clients": 2,
                  "client_ip": socket.gethostbyname(socket.gethostname()),
                  "ssh_host": config["host"], "direct_api_blocked": direct_api_blocked,
                  "unauthenticated_profile_http": 403, "client_fps_limit": 60,
                  "scope": "Separate Docker bridge network namespace, real SSH, published Godot clients. Not a public ALB/NLB or user's external network test."}
        Path("/evidence/verification.json").write_text(json.dumps(report, indent=2) + "\n")
        print("REMOTE_SSH_LOGIN_PASS separate_network=ok accounts=2 profiles=ok wrong_password=denied gameplay=ok")
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


def host_runner():
    from test_accounts import account
    evidence = ROOT / "artifacts/remote-ssh-login"
    evidence.mkdir(exist_ok=True)
    with (evidence / "build.log").open("w") as log:
        subprocess.run(["docker", "build", "-f", "infra/ssh-test-client.Dockerfile",
                        "-t", IMAGE, "."], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=180)
    host = json.loads(subprocess.check_output([
        "docker", "network", "inspect", "bridge", "--format", "{{json .IPAM.Config}}"], text=True))[0]["Gateway"]
    sshd_pid = None
    with tempfile.TemporaryDirectory(prefix="im-remote-login-") as temp:
        temp = Path(temp)
        container_name = temp.name
        try:
            credentials = []
            for index in range(2):
                value = account("network-" + str(index))
                credentials.append({key: value[key] for key in ("username", "password")})
            for name in ("host", "identity"):
                subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(temp / name)], check=True)
            with socket.socket() as sock:
                sock.bind((host, 0))
                port = sock.getsockname()[1]
            settings = {"accounts": credentials, "host": host, "port": port, "user": getpass.getuser()}
            private = temp / "config.json"
            private.write_text(json.dumps(settings))
            private.chmod(0o600)
            (temp / "known_hosts").write_text(f"[{host}]:{port} " + (temp / "host.pub").read_text())
            config = temp / "sshd_config"
            config.write_text(f"""Port {port}
ListenAddress {host}
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
            with (evidence / "test.log").open("w") as output:
                subprocess.run([
                    "docker", "run", "--rm", "--name", container_name, "--network", "bridge",
                    "-v", f"{temp}:/private:ro", "-v", f"{ROOT / 'tools'}:/source/tools:ro",
                    "-v", f"{ROOT / 'tests'}:/source/tests:ro", "-v", f"{evidence}:/evidence",
                    IMAGE, "/source/tools/test_remote_ssh_login.py", "--client-runner"],
                    stdout=output, stderr=subprocess.STDOUT, check=True, timeout=100)
            print((evidence / "test.log").read_text())
        finally:
            subprocess.run(["docker", "rm", "-f", container_name], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, check=False, timeout=15)
            if sshd_pid:
                subprocess.run(["sudo", "-n", "kill", str(sshd_pid)], check=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--client-runner", action="store_true")
    if parser.parse_args().client_runner:
        client_runner()
    else:
        host_runner()
