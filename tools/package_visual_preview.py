"""Export local desktop previews and test the packaged Linux game, without publishing."""
import hashlib
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip())
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = ROOT / "artifacts" / "visual-preview" / f"{commit[:12]}-{stamp}"
    output.mkdir(parents=True, exist_ok=False)
    logs = output / "logs"
    logs.mkdir()
    report = {
        "commit": commit, "worktree_dirty": dirty,
        "status": "building", "checks": [], "archives": {},
        "scope": "Local offline desktop preview. Not published. Windows execution and physical GPU performance unverified.",
    }

    def save():
        (output / "verification.json").write_text(json.dumps(report, indent=2) + "\n")

    def run(name, args, marker=None, env=None, cwd=ROOT, timeout=120):
        with (logs / f"{name}.log").open("w") as log:
            completed = subprocess.run(args, cwd=cwd, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=timeout)
        text = (logs / f"{name}.log").read_text()
        if completed.returncode or "SCRIPT ERROR:" in text or "Assertion failed" in text or (marker and marker not in text):
            raise RuntimeError(f"{name} failed; inspect {logs / (name + '.log')}")
        report["checks"].append(name)
        save()

    save()
    print(f"PREVIEW_DIRECTORY {output}", flush=True)
    try:
        # Export an isolated copy so ongoing source edits cannot alter the build.
        # Import caches and editor credentials are deliberately excluded.
        source = output / "source" / "client"
        shutil.copytree(ROOT / "client", source,
                        ignore=shutil.ignore_patterns(".godot", ".git", ".env*", "*.pem", "*.key", "*.keystore"))
        manifest = {}
        for path in sorted(source.rglob("*")):
            if path.is_file():
                manifest[path.relative_to(source).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        encoded = json.dumps(manifest, sort_keys=True).encode()
        source_hash = hashlib.sha256(encoded).hexdigest()
        report["source_sha256"] = source_hash
        (output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        save()
        godot = str(ROOT / "tools/godot")
        run("import", [godot, "--headless", "--path", str(source), "--editor", "--import"], timeout=600)
        for platform in ["Linux", "Windows"]:
            package = output / platform
            package.mkdir()
            if platform == "Linux":
                run("export-linux", [godot, "--headless", "--path", str(source),
                                     "--export-pack", "Linux", str(package / "IronMeridian.pck")])
                shutil.copy2(ROOT / "tools/godot", package / "IronMeridian")
            else:
                run("export-windows", [godot, "--headless", "--path", str(source),
                                       "--export-release", "Windows", str(package / "IronMeridian.exe")])
            shutil.copy2(ROOT / "LICENSE", package / "LICENSE")
            shutil.copy2(source / "assets/realism/LICENSE.md", package / "ASSET-NOTICES.md")
            shutil.copy2(source / "assets/realism/SOURCES.json", package / "ASSET-SOURCES.json")
            for notice in ["GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"]:
                # Official notices retained by the previous local preview build.
                shutil.copy2(ROOT / "artifacts/visual-preview" / notice, package / notice)
            entry = "IronMeridian.exe" if platform == "Windows" else "./IronMeridian"
            (package / "README.txt").write_text(
                f"Iron Meridian — local visual preview\nBase commit {commit}\nSource snapshot {source_hash}\n\n"
                f"Extract the ZIP, then launch {entry}. No Godot installation or play.sh required.\n"
                "Choose offline SOLO or DUO; an account is not required for offline play.\n"
                "This preview includes the current weapon, foliage, lighting and roof assets.\n"
                "Online servers require matching world/content builds; this package does not update the live service.\n"
                "Desktop defaults to Forward+. If needed, launch with --rendering-method gl_compatibility.\n"
                "Linux needs a desktop graphics environment and system OpenGL/Vulkan libraries.\n"
                "Windows executable is unsigned; it was exported here but not run on Windows hardware.\n"
                "Graphics remain under development; this is not the finished visual-quality target.\n"
            )
            (package / "build.json").write_text(json.dumps({
                "commit": commit, "platform": platform,
                "worktree_dirty": dirty, "source_sha256": source_hash,
                "manifest": json.loads((source / "protocol.json").read_text()),
            }, indent=2) + "\n")
        # Launch from outside the source/package directory, with a fresh profile,
        # proving automatic adjacent PCK discovery and offline startup.
        with tempfile.TemporaryDirectory(prefix="iron-preview-check-") as scratch:
            env = os.environ.copy()
            env["XDG_DATA_HOME"] = scratch
            executable = str(output / "Linux/IronMeridian")
            run("packaged-offline", [executable, "--headless", "--", "--smoke"],
                "OFFLINE_SMOKE_PASS", env=env, cwd=scratch)
            run("packaged-roof-collision", [executable, "--headless", "--script",
                str(ROOT / "tests/roof_collision.gd")], "ROOF_COLLISION_PASS", env=env, cwd=scratch)
            run("packaged-aim-alignment", [executable, "--headless", "--script",
                str(ROOT / "tests/aim_alignment.gd")], "AIM_ALIGNMENT_PASS", env=env, cwd=scratch)
            run("packaged-workshop-traversal", [executable, "--headless", "--script",
                str(ROOT / "tests/west_workshop_traversal_review.gd")],
                "WEST_WORKSHOP_TRAVERSAL_PASS", env=env, cwd=scratch)
        for platform in ["Linux", "Windows"]:
            archive = output / f"IronMeridian-{platform}-VisualPreview.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
                for path in sorted((output / platform).rglob("*")):
                    if path.is_file():
                        zipped.write(path, Path(f"IronMeridian-{platform}") / path.relative_to(output / platform))
            with zipfile.ZipFile(archive) as zipped:
                corrupt_entry = zipped.testzip()
                if corrupt_entry is not None:
                    raise RuntimeError(f"{platform} archive CRC failed: {corrupt_entry}")
            report["checks"].append(f"archive-{platform.lower()}-crc")
            with archive.open("rb") as stream:
                checksum = hashlib.sha256()
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    checksum.update(chunk)
                report["archives"][platform] = {"file": archive.name, "sha256": checksum.hexdigest()}
        report["status"] = "packaged-and-linux-verified"
        save()
        print(f"VISUAL_PREVIEW_PASS {output}", flush=True)
    except Exception as error:
        report.update(status="failed", failure=str(error))
        save()
        raise


if __name__ == "__main__":
    main()
