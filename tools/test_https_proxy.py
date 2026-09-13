"""Validate the public proxy and exercise local trusted TLS against the live API."""
import json
from pathlib import Path
import ssl
import subprocess
import tempfile
import time
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
IMAGE = "caddy:2.10.2-alpine"


def output(args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def main():
    container = "iron-https-check-" + uuid.uuid4().hex[:10]
    report = {"status": "running", "scope": "Local trusted TLS and reverse proxy; not public DNS, ACME or UDP reachability"}
    path = ROOT / "artifacts/https-proxy-verification.json"
    try:
        subprocess.run(["docker", "run", "--rm", "--network", "none",
                        "-e", "PUBLIC_HOST=game.example.invalid",
                        "-v", str(ROOT / "infra/Caddyfile") + ":/etc/caddy/Caddyfile:ro",
                        IMAGE, "caddy", "validate", "--config", "/etc/caddy/Caddyfile"],
                       check=True, stdout=subprocess.DEVNULL)
        api = output(["docker", "compose", "ps", "-q", "api"])
        networks = json.loads(output(["docker", "inspect", "--format",
                                      "{{json .NetworkSettings.Networks}}", api]))
        network = next(iter(networks))
        with tempfile.TemporaryDirectory(prefix="iron-https-") as temporary:
            folder = Path(temporary)
            # Same proxy block; local CA replaces public ACME only for this test.
            config = (ROOT / "infra/Caddyfile").read_text().replace(
                "{$PUBLIC_HOST} {", "localhost {\n\ttls internal")
            (folder / "Caddyfile").write_text(config)
            subprocess.run(["docker", "run", "-d", "--name", container,
                            "--network", network, "-p", "127.0.0.1::443",
                            "-v", str(folder / "Caddyfile") + ":/etc/caddy/Caddyfile:ro",
                            IMAGE], check=True, stdout=subprocess.DEVNULL)
            port = output(["docker", "port", container, "443/tcp"]).rsplit(":", 1)[1]
            certificate = folder / "root.crt"
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                result = subprocess.run(["docker", "cp", container + ":/data/caddy/pki/authorities/local/root.crt",
                                         str(certificate)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if result.returncode == 0:
                    break
                time.sleep(0.2)
            context = ssl.create_default_context(cafile=str(certificate))
            checks = {}
            for endpoint in ["health", "protocol"]:
                with urllib.request.urlopen("http://127.0.0.1:8000/" + endpoint, timeout=5) as response:
                    expected = json.load(response)
                with urllib.request.urlopen(f"https://localhost:{port}/{endpoint}", context=context, timeout=5) as response:
                    assert response.status == 200
                    actual = json.load(response)
                assert actual == expected, endpoint
                checks[endpoint] = actual
            report.update(status="passed", checks=checks,
                          image_id=output(["docker", "image", "inspect", "--format", "{{.Id}}", IMAGE]),
                          certificate_verified=True, hostname_verified=True)
    except Exception as error:
        report.update(status="failed", error=type(error).__name__)
        raise
    finally:
        subprocess.run(["docker", "rm", "-f", "-v", container], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        path.write_text(json.dumps(report, indent=2) + "\n")
    print("HTTPS_PROXY_PASS trusted_certificate=ok hostname=ok health=ok protocol=ok")


if __name__ == "__main__":
    main()
