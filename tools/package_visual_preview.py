"""Export local desktop previews and test the packaged Linux game, without publishing."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    if subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT).strip():
        raise SystemExit("Commit the preview source before packaging.")
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    output = ROOT / "artifacts" / "visual-preview" / commit[:12]
    output.mkdir(parents=True, exist_ok=False)
    logs = output / "logs"
    logs.mkdir()
    report = {
        "commit": commit, "status": "building", "checks": [], "archives": {},
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
        godot = str(ROOT / "tools/godot")
        run("import", [godot, "--headless", "--path", str(ROOT / "client"), "--editor", "--import"])
        for platform in ["Linux", "Windows"]:
            package = output / platform
            package.mkdir()
            if platform == "Linux":
                run("export-linux", [godot, "--headless", "--path", str(ROOT / "client"),
                                     "--export-pack", "Linux", str(package / "IronMeridian.pck")])
                shutil.copy2(ROOT / "tools/godot", package / "IronMeridian")
            else:
                run("export-windows", [godot, "--headless", "--path", str(ROOT / "client"),
                                       "--export-release", "Windows", str(package / "IronMeridian.exe")])
            shutil.copy2(ROOT / "LICENSE", package / "LICENSE")
            shutil.copy2(ROOT / "client/assets/realism/LICENSE.md", package / "ASSET-NOTICES.md")
            shutil.copy2(ROOT / "client/assets/realism/SOURCES.json", package / "ASSET-SOURCES.json")
            for notice in ["GODOT-LICENSE.txt", "GODOT-COPYRIGHT.txt"]:
                # Official notices retained by the previous local preview build.
                shutil.copy2(ROOT / "artifacts/visual-preview" / notice, package / notice)
            entry = "IronMeridian.exe" if platform == "Windows" else "./IronMeridian"
            (package / "README.txt").write_text(
                f"Iron Meridian — local visual preview\nBuild {commit}\n\n"
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
                "manifest": json.loads((ROOT / "client/protocol.json").read_text()),
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
        for platform in ["Linux", "Windows"]:
            archive = output / f"IronMeridian-{platform}-VisualPreview.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
                for path in sorted((output / platform).rglob("*")):
                    if path.is_file():
                        zipped.write(path, Path(f"IronMeridian-{platform}") / path.relative_to(output / platform))
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
