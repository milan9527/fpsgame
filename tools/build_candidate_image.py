"""Build and verify an immutable candidate server image without starting services."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-dir", type=Path, required=True)
    options = parser.parse_args()
    directory = options.candidate_dir.resolve()
    _, candidate = candidate_command(directory)
    package = directory / "IronMeridian-Linux"
    tag = "iron-meridian-candidate:" + candidate["commit"][:12]
    report_path = directory / "server-image.json"
    report = {"status": "building", "tag": tag, "commit": candidate["commit"],
              "archive_sha256": candidate["sha256"], "pck_sha256": candidate["pck_sha256"]}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    container = None
    try:
        with (directory / "logs/server-image-build.log").open("w") as stream:
            subprocess.run(["docker", "build", "-f", str(ROOT / "infra/packaged-game.Dockerfile"),
                            "--label", "org.opencontainers.image.revision=" + candidate["commit"],
                            "-t", tag, str(package)], stdout=stream, stderr=subprocess.STDOUT,
                           check=True, timeout=600)
        image_id = subprocess.check_output(["docker", "image", "inspect", tag,
                                           "--format", "{{.Id}}"], text=True).strip()
        metadata = json.loads(subprocess.check_output(["docker", "image", "inspect", image_id], text=True))[0]
        assert metadata["Config"]["User"] == "game"
        container = subprocess.check_output(["docker", "create", "--network", "none", image_id],
                                            text=True).strip()
        with tempfile.TemporaryDirectory(prefix="iron-image-check-") as temp:
            for name in ("IronMeridian", "IronMeridian.pck", "build.json"):
                copied = Path(temp) / name
                subprocess.run(["docker", "cp", container + ":/app/" + name, str(copied)], check=True,
                               stdout=subprocess.DEVNULL)
                with copied.open("rb") as image_file, (package / name).open("rb") as source_file:
                    assert hashlib.file_digest(image_file, "sha256").digest() == hashlib.file_digest(source_file, "sha256").digest()
            with (directory / "logs/server-image-smoke.log").open("w") as stream:
                subprocess.run(["docker", "run", "--rm", "--network", "none", image_id,
                                "/app/IronMeridian", "--headless", "--main-pack", "/app/IronMeridian.pck",
                                "--", "--smoke"], stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=45)
        text = (directory / "logs/server-image-smoke.log").read_text()
        assert "OFFLINE_SMOKE_PASS" in text and not any(s in text for s in
                    ("ERROR:", "Assertion failed", "ObjectDB instances leaked"))
        candidate_command(directory)
        report.update(status="passed", image_id=image_id, runtime_bytes="match candidate archive",
                      nonroot=True, isolated_smoke="passed", deployed=False)
        print("CANDIDATE_IMAGE_PASS " + json.dumps(report), flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        raise
    finally:
        if container:
            subprocess.run(["docker", "rm", "-f", container], check=True, stdout=subprocess.DEVNULL)
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
