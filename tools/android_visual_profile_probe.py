"""Short native-profiler capability probe; not a gameplay performance test."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import time
import sys


def main():
    gameplay = os.environ.get("ANDROID_VISUAL_PROFILE_GAMEPLAY") == "1"
    duration = (int(os.environ.get("ANDROID_PRESENT_SECONDS", "25")) +
                int(os.environ.get("ANDROID_ACTIVE_WARMUP_SECONDS", "30")) + 400
                if gameplay else 90)
    out = Path(os.environ["DEVICEFARM_LOG_DIR"])
    bundle = Path(__file__).resolve().parents[1] / "tools"
    runtime = bundle / "runtime"
    raw = out / "native-visual-profile.jsonl"
    log = out / "native-visual-collector.log"
    report = {"purpose": "native visual profiler support only",
              "acceptance_evidence": False, "frames": 0}
    if gameplay:
        report["purpose"] = "native visual stages during continuous touch gameplay"
    collector = None
    executable_dir = None

    def adb(*args):
        return subprocess.check_output(["adb", *args], text=True,
                                       stderr=subprocess.STDOUT, timeout=30)

    try:
        # Device Farm extracts packages under a different owner. Copy bytes
        # into our own directory before setting executable permissions.
        executable_dir = Path(tempfile.mkdtemp(prefix="native-visual-probe-"))
        engine, loader = prepare_executables(bundle, executable_dir)
        report["device"] = adb("shell", "getprop", "ro.product.model").strip()
        report["android"] = adb("shell", "getprop", "ro.build.version.release").strip()
        adb("shell", "am", "force-stop", "org.ironmeridian.game")
        with log.open("x") as stream:
            collector = subprocess.Popen(
                [str(loader), "--library-path", str(runtime), str(engine),
                 "--headless", "--path", str(out), "--script",
                 str(bundle / "capture_godot_visual_profile.gd"), "--", str(raw), str(duration), "6007"],
                stdout=stream, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + 20
            while "VISUAL_PROFILE_LISTENING" not in log.read_text():
                if collector.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Native collector did not listen; inspect collector log")
                time.sleep(0.25)
            adb("reverse", "tcp:6007", "tcp:6007")
            if gameplay:
                try:
                    child = subprocess.run(
                        [sys.executable, str(Path(__file__).with_name("android_native_walkthrough.py"))],
                        timeout=duration - 10)
                    report["gameplay_returncode"] = child.returncode
                finally:
                    # Disconnect gracefully so buffered native frames survive
                    # a failed walkthrough (for example player death).
                    adb("shell", "am", "force-stop", "org.ironmeridian.game")
                    report["collector_returncode"] = collector.wait(timeout=15)
            else:
                report["launch"] = adb(
                    "shell", "am", "start", "-W", "-n",
                    "org.ironmeridian.game/com.godot.game.GodotApp",
                    "--esa", "command_line_params", "--remote-debug,tcp://127.0.0.1:6007")
                report["collector_returncode"] = collector.wait(timeout=110)
        if raw.exists():
            for line in raw.read_text().splitlines():
                record = json.loads(line)
                if record.get("message") == "visual:profile_frame":
                    report["frames"] += 1
        report["supported"] = report["frames"] > 0 and report["collector_returncode"] == 0
        if not report["supported"]:
            raise RuntimeError("Existing APK did not provide visual profiler frames")
        if gameplay and report["gameplay_returncode"] != 0:
            raise RuntimeError("Gameplay failed; preserved native frames are diagnostic evidence only")
    except Exception as exc:
        report["error"] = str(exc)
        raise
    finally:
        if collector is not None and collector.poll() is None:
            collector.terminate()
            try:
                collector.wait(timeout=5)
            except subprocess.TimeoutExpired:
                collector.kill()
                collector.wait(timeout=5)
        for args in [("reverse", "--remove", "tcp:6007"),
                     ("shell", "am", "force-stop", "org.ironmeridian.game")]:
            try:
                adb(*args)
            except Exception as exc:
                report.setdefault("cleanup_errors", []).append(str(exc))
        report_name = "native-visual-gameplay.json" if gameplay else "native-visual-probe.json"
        (out / report_name).write_text(json.dumps(report, indent=2))
        if executable_dir is not None:
            shutil.rmtree(executable_dir)


def prepare_executables(bundle, destination):
    engine = destination / "godot"
    loader = destination / "ld-linux-x86-64.so.2"
    for source, target in [
        (bundle / "godot", engine),
        (bundle / "runtime" / loader.name, loader),
    ]:
        shutil.copyfile(source, target)
        target.chmod(0o700)
    return engine, loader


if __name__ == "__main__":
    main()
