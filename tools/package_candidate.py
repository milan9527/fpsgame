"""Build an isolated, verified Linux candidate without replacing the published release."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CASES = [
    "candidate_manifest",
    "team_rules", "rescue_rules", "party_team_rules", "party_lobby_rules",
    "duo_disconnect_rules", "duo_spectator", "team_hud", "team_pings",
    "local_duo_profile", "duo_checkpoint", "checkpoint_rules", "bindings_rules",
    "heal_cancel_rules", "bot_hazards_rules", "bot_utilities_rules",
    "foregrip_rules", "input_timeout_rules", "damage_indicators_rules",
    "zone_rules", "inventory_rules", "death_loot_rules", "drop_rules",
    "voice_resampler", "voice_relay", "voice_playback", "voice_capture",
    "vehicle_slopes", "vehicle_spectator",
]


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
        raise SystemExit("Commit source changes before building a traceable candidate.")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = json.loads((ROOT / "client/protocol.json").read_text())
    candidates = ROOT / "artifacts/candidates"
    candidates.mkdir(exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix=f"{manifest['client_version']}-{commit[:8]}-", dir=candidates))
    package = output / "IronMeridian-Linux"
    package.mkdir()
    logs = output / "logs"
    logs.mkdir()
    report = {"status": "building", "commit": commit, "manifest": manifest, "checks": [],
              "scope": "Packed offline rules; online deployment and physical audio devices require separate verification."}
    report_path = output / "verification.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"CANDIDATE_DIRECTORY {output}", flush=True)

    def run(name, command, marker=None, env=None, timeout=45):
        print(f"CHECK {name}", flush=True)
        start = time.monotonic()
        log = logs / (name + ".log")
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=package, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        text = log.read_text()
        if result.returncode or (marker and marker not in text) or re.search(
                r"SCRIPT ERROR|Assertion failed|ObjectDB instances leaked|ERROR:", text):
            raise RuntimeError(f"{name} failed; inspect {log}")
        report["checks"].append({"name": name, "seconds": round(time.monotonic() - start, 2),
                                 "log": str(log.relative_to(output))})
        report_path.write_text(json.dumps(report, indent=2) + "\n")

    try:
        run("import", [str(ROOT / "tools/godot"), "--headless", "--path",
                       str(ROOT / "client"), "--editor", "--quit"], timeout=90)
        run("export", [str(ROOT / "tools/godot"), "--headless", "--path",
                       str(ROOT / "client"), "--export-pack", "Linux",
                       str(package / "IronMeridian.pck")], timeout=90)
        shutil.copy2(ROOT / "tools/godot", package / "IronMeridian")
        shutil.copy2(ROOT / "LICENSE", package / "LICENSE")
        shutil.copy2(ROOT / "docs/PLAYER_GUIDE.md", package / "PLAYER_GUIDE.md")
        shutil.copytree(ROOT / "docs", package / "docs", ignore=shutil.ignore_patterns("*~"))
        (package / "build.json").write_text(json.dumps({"commit": commit, **manifest}, indent=2) + "\n")
        launcher = package / "play.sh"
        launcher.write_text('#!/usr/bin/env bash\nset -euo pipefail\ncd "$(dirname "$0")"\nexec ./IronMeridian --main-pack IronMeridian.pck "$@"\n')
        launcher.chmod(0o755)
        (package / "CANDIDATE.txt").write_text(
            f"Development candidate {manifest['client_version']}, commit {commit}.\n"
            "Run ./play.sh on a Linux x86_64 desktop with OpenGL 3.3.\n"
            "Offline SOLO and DUO require no account. Online requires a compatible protocol "
            f"{manifest['protocol']} server. Existing protocol 15 services are incompatible.\n"
            "This candidate is not the published 0.34 release or a finished commercial game.\n"
        )
        with tempfile.TemporaryDirectory(prefix="iron-candidate-profile-") as profile:
            for directory in ("duo-profile", "duo-checkpoint"):
                Path(profile, directory).mkdir()
            env = os.environ.copy()
            env.update({"XDG_DATA_HOME": profile, "LOCAL_TEST_ROOT": profile + "/duo-profile",
                        "CHECKPOINT_TEST_ROOT": profile + "/duo-checkpoint",
                        "EXPECTED_CANDIDATE_MANIFEST": json.dumps(manifest)})
            for name in CASES:
                script = ROOT / "tests" / (name + ".gd")
                markers = re.findall(r'print\("([A-Z0-9_]+_PASS)', script.read_text())
                if len(markers) != 1:
                    raise RuntimeError(f"{name} requires an explicit single success marker")
                run(name, [str(launcher), "--headless", "--script", str(script)],
                    markers[0], env, timeout=60 if name == "vehicle_slopes" else 45)
        # Export must not have generated uncommitted source assets or changed the build.
        if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
            raise RuntimeError("Source changed during candidate creation; commit and rebuild.")
        archive = output / "IronMeridian-Linux-x86_64.tar.gz"
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(package, arcname=package.name)
        report.update(status="passed", archive=archive.name, sha256=digest(archive),
                      pck_sha256=digest(package / "IronMeridian.pck"))
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(f"CANDIDATE_PASS checks={len(report['checks'])} archive={archive} sha256={report['sha256']}", flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        raise


if __name__ == "__main__":
    main()
