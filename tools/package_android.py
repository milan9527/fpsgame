"""Build a signed Android APK from the deployed revision plus the touch interface."""
import hashlib
import io
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/android-build"
RELEASE = "484d98d958a0973d5dc630ce6474dcdcba950035"
API = "https://d3j1sc8stx5n1c.cloudfront.net/api"


def main():
    source = OUT / "source"
    if source.exists():
        raise SystemExit("Preserve or move the previous Android source build before rebuilding.")
    source.mkdir(parents=True)
    raw = subprocess.check_output(["git", "archive", RELEASE, "client"], cwd=ROOT)
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        archive.extractall(source, filter="data")
    for relative in ["scripts/game.gd", "scripts/interface.gd"]:
        path = source / "client" / relative
        text = path.read_text()
        assert text.count('"http://127.0.0.1:8000"') == 1
        path.write_text(text.replace('"http://127.0.0.1:8000"', json.dumps(API)))
    from client_login_patch import apply
    apply(source / "client")
    from client_aim_patch import apply as apply_aim_fix
    apply_aim_fix(source / "client")
    game_path = source / "client/scripts/game.gd"
    text = game_path.read_text()
    current = (ROOT / "client/scripts/game.gd").read_text()
    hook = current[current.index('\t\tif OS.has_feature("android")'):current.index('\t\tif smoke:', current.index('\t\tif OS.has_feature("android")'))]
    assert text.count("\t\tui.local_history_requested.connect(show_local_history)\n") == 1
    text = text.replace("\t\tui.local_history_requested.connect(show_local_history)\n",
                        "\t\tui.local_history_requested.connect(show_local_history)\n" + hook)
    game_path.write_text(text)
    mobile = ROOT / "client/scripts/mobile_controls.gd"
    shutil.copy2(mobile, source / "client/scripts/mobile_controls.gd")
    shutil.copy2(ROOT / "client/icon.svg", source / "client/icon.svg")
    shutil.copy2(ROOT / "client/export_presets.cfg", source / "client/export_presets.cfg")
    project = source / "client/project.godot"
    text = project.read_text().replace("[display]\n", "[display]\nwindow/handheld/orientation=0\n")
    text = text.replace('config/name="Iron Meridian"', 'config/name="Iron Meridian"\nconfig/icon="res://icon.svg"')
    text = text.replace("[rendering]\n", "[rendering]\ntextures/vram_compression/import_etc2_astc=true\n")
    # Native touch events drive the game; mouse emulation remains available for GUI widgets.
    text += '\n[input_devices]\npointing/emulate_touch_from_mouse=false\npointing/emulate_mouse_from_touch=true\n'
    project.write_text(text)
    signing = ROOT / "artifacts/android-signing"
    signing.mkdir(exist_ok=True, mode=0o700)
    password_file = signing / "credentials.json"
    if not password_file.exists():
        with os.fdopen(os.open(password_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as file:
            json.dump({"password": secrets.token_hex(32)}, file)
    password = json.loads(password_file.read_text())["password"]
    keystore = signing / "release.keystore"
    env = dict(os.environ, IRON_ANDROID_KEY_PASSWORD=password,
               GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(keystore),
               GODOT_ANDROID_KEYSTORE_RELEASE_USER="iron-meridian",
               GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=password)
    if not keystore.exists():
        with (OUT / "signing-setup.log").open("w") as log:
            subprocess.run(["keytool", "-genkeypair", "-keystore", str(keystore),
                "-alias", "iron-meridian", "-keyalg", "RSA", "-keysize", "3072",
                "-validity", "10000", "-dname", "CN=Iron Meridian",
                "-storepass:env", "IRON_ANDROID_KEY_PASSWORD", "-keypass:env", "IRON_ANDROID_KEY_PASSWORD"],
                env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
        keystore.chmod(0o600)
    config = OUT / "editor-config/godot"
    config.mkdir(parents=True, exist_ok=True)
    java = Path(shutil.which("java")).resolve().parent.parent
    (config / "editor_settings-4.4.tres").write_text(
        '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
        f'export/android/java_sdk_path = "{java}"\n'
        f'export/android/android_sdk_path = "{ROOT / "artifacts/android-sdk"}"\n')
    env["XDG_CONFIG_HOME"] = str(config.parent)
    apk = ROOT / "artifacts/IronMeridian-Android.apk"
    for name, cmd in [
        ("import", ["xvfb-run", "-a", str(ROOT / "tools/godot"), "--rendering-method", "gl_compatibility",
                    "--audio-driver", "Dummy", "--path", str(source / "client"), "--editor", "--import"]),
        ("export", [str(ROOT / "tools/godot"), "--headless", "--path", str(source / "client"),
                    "--export-release", "Android", str(apk)]),
    ]:
        with (OUT / (name + ".log")).open("w") as log:
            subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240, check=True)
        text = (OUT / (name + ".log")).read_text()
        if "SCRIPT ERROR" in text or "ERROR:" in text:
            raise RuntimeError("Android " + name + " failed; inspect its log")
    signer = ROOT / "artifacts/android-sdk/build-tools/35.0.0/apksigner"
    with (OUT / "signature-verification.log").open("w") as log:
        subprocess.run([str(signer), "verify", "--verbose", "--print-certs", str(apk)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    report = {"apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
              "size": apk.stat().st_size, "source_commit": RELEASE, "default_api": API,
              "touch_source_sha256": hashlib.sha256(mobile.read_bytes()).hexdigest(),
              "package": "org.ironmeridian.game", "version_code": 3803,
              "architectures": ["arm64-v8a", "x86_64"], "signed": True}
    (OUT / "build.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
