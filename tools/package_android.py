"""Build a signed Android APK from a manifest of the current working tree."""
import hashlib
import json
import os
import re
from pathlib import Path
import secrets
import shutil
import subprocess
from android_texture_policy import apply_texture_policy
from android_manifest_fix import repair_apk

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("ANDROID_BUILD_DIR", str(ROOT / "artifacts/android-build"))).resolve()
RELEASE = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
API = "https://d3j1sc8stx5n1c.cloudfront.net/api"
VERSION_CODE = 20261180
VERSION_NAME = "0.52.188-android.20261008"
APK_NAME = "IronMeridian-Android-0.52.188-20261008.apk"


def main():
    source = OUT / "source"
    resume = os.environ.get("ANDROID_RESUME_BUILD") == "1"
    if source.exists() and not resume:
        raise SystemExit("Preserve or move the previous Android source build before rebuilding.")
    if not resume:
        if os.environ.get("ANDROID_SOURCE_ROOT"):
            source_root = Path(os.environ["ANDROID_SOURCE_ROOT"]).resolve()
            source_root.mkdir(parents=True, exist_ok=False)
            OUT.mkdir(parents=True, exist_ok=True)
            source.symlink_to(source_root, target_is_directory=True)
        else:
            source.mkdir(parents=True)
        shutil.copytree(ROOT / "client", source / "client",
                    ignore=shutil.ignore_patterns(".godot", ".git", ".env*", "*.pem", "*.key", "*.keystore"))
        manifest = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in sorted(source.rglob("*")) if p.is_file()}
        (OUT / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    else:
        manifest = json.loads((OUT / "source-manifest.json").read_text())
        for relative, digest in manifest.items():
            assert hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() == digest, relative
    for relative in ["scripts/game.gd", "scripts/interface.gd"]:
        path = source / "client" / relative
        text = path.read_text()
        assert text.count('"http://127.0.0.1:8000"') == 1 or (resume and json.dumps(API) in text)
        path.write_text(text.replace('"http://127.0.0.1:8000"', json.dumps(API)))
    texture_policy = apply_texture_policy(source / "client")
    (OUT / "texture-policy.json").write_text(json.dumps(texture_policy, indent=2) + "\n")
    mobile = source / "client/scripts/mobile_controls.gd"
    preset = source / "client/export_presets.cfg"
    preset.write_text(preset.read_text().replace("version/code=3804", f"version/code={VERSION_CODE}")
                      .replace('version/name="0.38.0-android.4"', f'version/name="{VERSION_NAME}"')
                      .replace('package/signed=true', 'package/signed=false'))
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
    apk = OUT / APK_NAME
    for name, cmd in [
        # Embedded GLB textures need a rendering backend during scene import.
        ("import", ["xvfb-run", "-a", str(ROOT / "tools/godot"), "--rendering-method",
                    "gl_compatibility", "--audio-driver", "Dummy",
                    "--path", str(source / "client"), "--editor", "--import"]),
        # Dummy rendering drops MultiMesh instance buffers when saving resources.
        ("terrain-bake", ["xvfb-run", "-a", str(ROOT / "tools/godot"),
                          "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                          "--path", str(source / "client"),
                          "--script", "res://tests/bake_android_terrain.gd"]),
        ("export", [str(ROOT / "tools/godot"), "--headless", "--path", str(source / "client"),
                    "--export-release", "Android", str(apk)]),
    ]:
        with (OUT / (name + ".log")).open("w") as log:
            subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=900, check=True)
        text = (OUT / (name + ".log")).read_text()
        if name == "terrain-bake" and "ANDROID_GROUND_VERIFIED grass_instances=" in text:
            # Godot 4.4 GLES3 reports two 32px texture allocations at shutdown,
            # after the baked MultiMesh buffers have passed read-back validation.
            # Preserve the raw log and allow only this exact engine diagnostic.
            text = re.sub(
                r"ERROR: Texture with GL ID of \d+: leaked 5460 bytes\.\n"
                r"   at: ~Utilities \(drivers/gles3/storage/utilities\.cpp:77\)\n",
                "", text,
            )
        if "SCRIPT ERROR" in text or "ERROR:" in text:
            raise RuntimeError("Android " + name + " failed; inspect its log")
    finalize_apk(apk, mobile, texture_policy, keystore, env)


def finalize_apk(apk, mobile, texture_policy, keystore, env):
    """Repair, sign and verify an exported APK, including recovered exports."""
    build_tools = ROOT / "artifacts/android-sdk/build-tools/35.0.0"
    signer = build_tools / "apksigner"
    repaired = OUT / "manifest-repaired.apk"
    aligned = OUT / "manifest-aligned.apk"
    try:
        patched = repair_apk(apk, repaired)
        if patched:
            subprocess.run([str(build_tools / "zipalign"), "-f", "-p", "4",
                            str(repaired), str(aligned)], check=True)
            aligned.replace(apk)
    finally:
        repaired.unlink(missing_ok=True)
        aligned.unlink(missing_ok=True)
    subprocess.run([str(signer), "sign", "--ks", str(keystore),
                    "--ks-key-alias", "iron-meridian", "--ks-pass",
                    "env:IRON_ANDROID_KEY_PASSWORD", "--key-pass",
                    "env:IRON_ANDROID_KEY_PASSWORD", str(apk)], env=env,
                   timeout=180, check=True)
    with (OUT / "manifest-verification.log").open("w") as log:
        subprocess.run([str(build_tools / "aapt"), "dump", "badging", str(apk)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    with (OUT / "signature-verification.log").open("w") as log:
        subprocess.run([str(signer), "verify", "--verbose", "--print-certs", str(apk)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    report = {"apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
              "size": apk.stat().st_size, "source_commit": RELEASE, "default_api": API,
              "touch_source_sha256": hashlib.sha256(mobile.read_bytes()).hexdigest(),
              "gyro_source_sha256": hashlib.sha256((ROOT / "client/scripts/gyro_aim.gd").read_bytes()).hexdigest(),
              "package": "org.ironmeridian.game", "version_code": VERSION_CODE, "version_name": VERSION_NAME,
              "source_manifest_sha256": hashlib.sha256((OUT / "source-manifest.json").read_bytes()).hexdigest(),
              "working_tree_snapshot": True,
              "texture_policy_sha256": hashlib.sha256((OUT / "texture-policy.json").read_bytes()).hexdigest(),
              "architectures": ["arm64-v8a", "x86_64"], "signed": True}
    (OUT / "build.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
