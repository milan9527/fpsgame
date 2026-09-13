"""Export the deployed game revision as a double-clickable Windows x64 package."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RELEASE = "484d98d958a0973d5dc630ce6474dcdcba950035"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=RELEASE)
    parser.add_argument("--api", default="https://d3j1sc8stx5n1c.cloudfront.net/api")
    args = parser.parse_args()
    if not args.api.startswith("https://") or any(c in args.api for c in ['"', "\n", "\\"]):
        raise ValueError("A valid HTTPS API address is required")
    output = ROOT / "artifacts/windows-build"
    source = output / "source"
    package = output / "IronMeridian-Windows"
    if source.exists() or package.exists():
        raise SystemExit("Existing build present. Preserve or move it before creating another build.")
    source.mkdir(parents=True)
    package.mkdir()
    package.chmod(0o755)
    revision = subprocess.check_output(
        ["git", "rev-parse", args.source], cwd=ROOT, text=True).strip()
    raw = subprocess.check_output(
        ["git", "archive", revision, "client", "LICENSE", "docs/PLAYER_GUIDE.md"], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        archive.extractall(source, filter="data")
    # Keep the game/server protocol unchanged. Only set the Windows distribution's
    # default connection address; saved player preferences still take precedence.
    patches = []
    for relative in ["scripts/game.gd", "scripts/interface.gd"]:
        path = source / "client" / relative
        content = path.read_text()
        if content.count('"http://127.0.0.1:8000"') != 1:
            raise ValueError("Review endpoint configuration for source revision " + revision)
        path.write_text(content.replace('"http://127.0.0.1:8000"', json.dumps(args.api)))
        patches.append(relative + ": default API URL")
    shutil.copy2(ROOT / "client/export_presets.cfg", source / "client/export_presets.cfg")
    for name, arguments in [
        ("import", ["--editor", "--import"]),
        ("export", ["--export-release", "Windows", str(package / "IronMeridian.exe")]),
    ]:
        command = ([str(ROOT / "tools/godot"), "--headless"] if name == "export" else
                   ["xvfb-run", "-a", str(ROOT / "tools/godot"), "--rendering-method", "gl_compatibility"])
        with (output / (name + ".log")).open("w") as log:
            subprocess.run([*command, "--audio-driver", "Dummy", "--path", str(source / "client"), *arguments],
                           stdout=log, stderr=subprocess.STDOUT, timeout=180, check=True)
        text = (output / (name + ".log")).read_text()
        if "SCRIPT ERROR" in text or "ERROR:" in text:
            raise RuntimeError("Export failed; inspect " + name + ".log")
    executable = package / "IronMeridian.exe"
    if executable.read_bytes()[:2] != b"MZ":
        raise RuntimeError("Expected a Windows PE executable")
    shutil.copy2(source / "LICENSE", package / "LICENSE.txt")
    shutil.copy2(source / "docs/PLAYER_GUIDE.md", package / "PLAYER_GUIDE.md")
    (package / "开始游戏.txt").write_text(
        "铁境行动 / Iron Meridian — Windows x64\n\n"
        "1. 在资源管理器中右键 ZIP，选择“全部解压”。\n"
        "2. 打开解压后的文件夹，双击 IronMeridian.exe。\n"
        "3. SOLO / OFFLINE 或 DUO / OFFLINE 无需账号。\n"
        "4. 联网在游戏内注册或登录。服务器地址已预填：\n"
        + args.api + "\n\n"
        "不需要 Godot、Python、play.sh 或 SSH；不要在 ZIP 内直接运行。\n"
        "需要 Windows 10/11 64 位及支持 OpenGL 3.3 的显卡驱动。\n"
        "这是未进行代码签名的便携开发版；Windows 可能显示发布者未知。\n"
        "存档位置：%APPDATA%\\Godot\\app_userdata\\Iron Meridian\n",
        encoding="utf-8-sig")
    manifest = json.loads((source / "client/protocol.json").read_text())
    manifest.update(source_commit=revision, platform="windows-x86_64", default_api=args.api,
                    distribution_patches=patches, signed=False,
                    exe_sha256=hashlib.sha256(executable.read_bytes()).hexdigest())
    (package / "build.json").write_text(json.dumps(manifest, indent=2) + "\n")
    archive_path = ROOT / "artifacts/IronMeridian-Windows-x86_64.zip"
    with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for file in sorted(package.iterdir()):
            archive.write(file, package.name + "/" + file.name)
    report = {"archive": str(archive_path), "sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
              "size": archive_path.stat().st_size, **manifest}
    (output / "build.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
