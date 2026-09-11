"""Validate a candidate's runtime files before launching packaged integration tests."""
import hashlib
import json
from pathlib import Path
import tarfile


def candidate_command(directory):
    directory = Path(directory).resolve()
    report = json.loads((directory / "verification.json").read_text())
    if report.get("status") != "passed":
        raise ValueError("Candidate has not passed its packaging checks")
    archive = directory / report["archive"]
    with archive.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != report["sha256"]:
            raise ValueError("Candidate archive checksum mismatch")
    package = directory / "IronMeridian-Linux"
    with tarfile.open(archive) as tar:
        for name in ("IronMeridian", "IronMeridian.pck", "play.sh", "build.json"):
            member = tar.extractfile("IronMeridian-Linux/" + name)
            if member is None:
                raise ValueError("Candidate runtime member missing: " + name)
            with member, (package / name).open("rb") as installed:
                if hashlib.file_digest(member, "sha256").digest() != hashlib.file_digest(installed, "sha256").digest():
                    raise ValueError("Candidate runtime differs from archive: " + name)
    build = json.loads((package / "build.json").read_text())
    if build != {"commit": report["commit"], **report["manifest"]}:
        raise ValueError("Candidate build metadata differs from report")
    return [str(package / "play.sh"), "--headless"], report
