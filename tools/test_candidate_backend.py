"""Exercise a candidate API image using disposable, isolated PostgreSQL and Redis."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile
import uuid
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--image", required=True)
    options = parser.parse_args()
    directory = options.candidate_dir.resolve()
    _, candidate = candidate_command(directory)
    image_id = subprocess.check_output(["docker", "image", "inspect", "--format", "{{.Id}}",
                                        options.image], text=True).strip()
    manifest = json.loads(subprocess.check_output(
        ["docker", "run", "--rm", "--network", "none", image_id, "python", "-c",
         "from pathlib import Path; print(Path('/app/app/protocol.json').read_text())"], text=True))
    assert manifest == candidate["manifest"]
    report_path = directory / "backend-verification.json"
    report = {"status": "running", "image_id": image_id, "manifest": manifest,
              "candidate_commit": candidate["commit"], "archive_sha256": candidate["sha256"]}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    with tempfile.TemporaryDirectory(prefix="candidate-backend-", dir=ROOT / "artifacts") as temp:
        config = Path(temp) / "compose.json"
        password = secrets.token_hex(24)
        environment = {"DATABASE_URL": f"postgresql+psycopg://iron:{password}@postgres/iron",
                       "REDIS_URL": "redis://redis:6379/0", "JWT_SECRET": secrets.token_hex(32),
                       "SERVER_SECRET": secrets.token_hex(32), "TEST_API": "http://api:8000",
                       "PYTHONPATH": "/app"}
        healthy = {"condition": "service_healthy"}
        specification = {"services": {
            "postgres": {"image": "postgres:16-alpine",
                         "environment": {"POSTGRES_USER": "iron", "POSTGRES_PASSWORD": password, "POSTGRES_DB": "iron"},
                         "tmpfs": ["/var/lib/postgresql/data"],
                         "healthcheck": {"test": ["CMD", "pg_isready", "-h", "127.0.0.1", "-U", "iron"],
                                         "interval": "1s", "timeout": "3s", "retries": 30}},
            "redis": {"image": "redis:7-alpine",
                      "healthcheck": {"test": ["CMD", "redis-cli", "ping"], "interval": "1s", "timeout": "3s", "retries": 30}},
            "api": {"image": image_id, "environment": environment,
                    "depends_on": {"postgres": healthy, "redis": healthy},
                    "healthcheck": {"test": ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"],
                                    "interval": "1s", "timeout": "3s", "retries": 30}},
            "tests": {"image": image_id, "environment": environment,
                      "volumes": [f"{ROOT / 'backend/tests'}:/app/tests:ro",
                                  f"{ROOT / 'tools'}:/app/tools:ro",
                                  f"{ROOT / 'client/protocol.json'}:/client/protocol.json:ro"],
                      "command": ["python", "-m", "pytest", "-q", "-p", "no:cacheprovider", "/app/tests"]}},
            "networks": {"default": {"internal": True}}}
        descriptor = os.open(config, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(descriptor, "w") as stream:
            json.dump(specification, stream)
        compose = ["docker", "compose", "-p", "iron-api-check-" + uuid.uuid4().hex[:10], "-f", str(config)]
        try:
            with (directory / "logs/backend-startup.log").open("w") as stream:
                subprocess.run(compose + ["up", "-d", "--wait", "--wait-timeout", "60", "api"],
                               stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=90)
            path = directory / "logs/backend-tests.log"
            with path.open("w") as stream:
                subprocess.run(compose + ["run", "--rm", "--no-deps", "tests"], stdout=stream,
                               stderr=subprocess.STDOUT, check=True, timeout=180)
            text = path.read_text()
            match = re.search(r"(\d+) passed", text)
            assert match and int(match.group(1)) >= 56 and "skipped" not in text, text[-1500:]
            report.update(status="passed", tests=int(match.group(1)), log="logs/backend-tests.log",
                          isolation="Internal Docker network, no host ports, disposable database and cache")
            print("CANDIDATE_BACKEND_PASS " + json.dumps(report), flush=True)
        except Exception as error:
            report.update(status="failed", failure=str(error))
            raise
        finally:
            subprocess.run(compose + ["down", "--volumes", "--remove-orphans"], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
            report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
