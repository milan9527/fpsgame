"""Upload and schedule a native touch walkthrough for an already uploaded APK."""
import hashlib
import io
import json
import math
import os
from pathlib import Path
import time
import zipfile

import boto3
import httpx

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ["ANDROID_BUILD_DIR"]).resolve()


def main():
    # Disable only for explicit recorder-overhead diagnostics; retain videos by default.
    video_capture_setting = os.environ.get("ANDROID_DEVICEFARM_VIDEO_CAPTURE", "1")
    if video_capture_setting not in ("0", "1"):
        raise ValueError("ANDROID_DEVICEFARM_VIDEO_CAPTURE must be 0 or 1")
    video_capture = video_capture_setting == "1"
    profile_game = os.environ.get("ANDROID_PROFILE_GAME") == "1"
    shader_sources = os.environ.get("ANDROID_COLLECT_SHADER_SOURCES") == "1"
    render_baseline = os.environ.get("ANDROID_RENDER_BASELINE") == "1"
    ground_materials = os.environ.get("ANDROID_GROUND_MATERIAL_DIAGNOSTIC") == "1"
    if ground_materials and (not profile_game or render_baseline or
                             os.environ.get("ANDROID_VISUAL_PROFILE_PROBE") == "1"):
        raise ValueError("Ground material diagnostic requires gameplay profiling")
    initial_route_probe = os.environ.get("ANDROID_INITIAL_ROUTE_PROBE") == "1"
    multitouch = os.environ.get("ANDROID_MULTITOUCH") == "1"
    system_trace = os.environ.get("ANDROID_SYSTEM_TRACE") == "1"
    trace_profile = os.environ.get("ANDROID_SYSTEM_TRACE_PROFILE", "scheduler")
    if trace_profile not in ("scheduler", "render", "joint"):
        raise ValueError("Unknown ANDROID_SYSTEM_TRACE_PROFILE")
    cpu_sample = os.environ.get("ANDROID_CPU_SAMPLE") == "1"
    visual_probe = os.environ.get("ANDROID_VISUAL_PROFILE_PROBE") == "1"
    visual_gameplay = os.environ.get("ANDROID_VISUAL_PROFILE_GAMEPLAY") == "1"
    if visual_gameplay and (not profile_game or visual_probe or render_baseline):
        raise ValueError("Visual gameplay requires profile-game without probe or render baseline")
    visual_engine = None
    visual_engine_sha256 = None
    visual_runtime = {}
    if visual_probe or visual_gameplay:
        if visual_probe and any((profile_game, render_baseline, initial_route_probe, multitouch,
                system_trace, cpu_sample)):
            raise ValueError("Visual support probe must run alone")
        visual_engine = Path(os.environ.get("ANDROID_VISUAL_PROFILE_GODOT",
                                            str(ROOT / "tools/godot")))
        with visual_engine.open("rb") as binary:
            header = binary.read(20)
        if header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
            raise ValueError("Visual collector requires a Linux x86_64 Godot binary")
        visual_engine_sha256 = hashlib.sha256(visual_engine.read_bytes()).hexdigest()
        # AL2 has glibc 2.26; use a private loader/runtime for the collector only.
        runtime_dir = Path(os.environ.get("ANDROID_VISUAL_PROFILE_RUNTIME", "/lib64"))
        for name in ("ld-linux-x86-64.so.2", "libc.so.6", "libm.so.6",
                     "libpthread.so.0", "libdl.so.2", "librt.so.1"):
            path = runtime_dir / name
            visual_runtime[name] = {"path": path,
                                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    if cpu_sample and render_baseline:
        raise ValueError("CPU sampling requires the native walkthrough")
    if system_trace and render_baseline:
        raise ValueError("System trace requires the native walkthrough")
    multitouch_jar = None
    multitouch_sha256 = None
    if multitouch:
        if render_baseline:
            raise ValueError("Multitouch requires the native walkthrough")
        jar_path = os.environ.get("ANDROID_MULTITOUCH_JAR")
        if not jar_path:
            raise ValueError("ANDROID_MULTITOUCH_JAR is required when multitouch is enabled")
        multitouch_jar = Path(jar_path).read_bytes()
        with zipfile.ZipFile(io.BytesIO(multitouch_jar)) as jar:
            if not jar.read("classes.dex").startswith(b"dex\n"):
                raise ValueError("Multitouch JAR must contain Android classes.dex")
        multitouch_sha256 = hashlib.sha256(multitouch_jar).hexdigest()
    if initial_route_probe and render_baseline:
        raise ValueError("Initial route probe requires the native walkthrough")
    if profile_game and render_baseline:
        raise ValueError("Choose gameplay profiling or static render baseline, not both")
    seconds = int(os.environ.get("ANDROID_PRESENT_SECONDS", "25"))
    warmup_seconds = int(os.environ.get("ANDROID_ACTIVE_WARMUP_SECONDS", "30"))
    if not 10 <= seconds <= 600 or not 0 <= warmup_seconds <= 600:
        raise ValueError("Presentation duration must be 10..600s and active warmup 0..600s")
    measurement_env = ("" if render_baseline else
                       f"ANDROID_PRESENT_SECONDS={seconds} "
                       f"ANDROID_ACTIVE_WARMUP_SECONDS={warmup_seconds} "
                       f"ANDROID_INITIAL_ROUTE_PROBE={int(initial_route_probe)} "
                       f"ANDROID_BUILDING_ROUTE={int(os.environ.get('ANDROID_BUILDING_ROUTE') == '1')} "
                       "ANDROID_COMBAT_VIEW_DIAGNOSTIC="
                       f"{int(os.environ.get('ANDROID_COMBAT_VIEW_DIAGNOSTIC') == '1')} ")
    if multitouch:
        measurement_env += "ANDROID_MULTITOUCH=1 "
    if ground_materials:
        measurement_env += "ANDROID_GROUND_MATERIAL_DIAGNOSTIC=1 "
    if system_trace:
        measurement_env += f"ANDROID_SYSTEM_TRACE=1 ANDROID_SYSTEM_TRACE_PROFILE={trace_profile} "
    if cpu_sample:
        measurement_env += "ANDROID_CPU_SAMPLE=1 "
    if visual_gameplay:
        measurement_env += "ANDROID_VISUAL_PROFILE_GAMEPLAY=1 "
    prior = json.loads((OUT / "devicefarm.json").read_text())
    client = boto3.client("devicefarm", region_name="us-west-2")
    package = OUT / "native-walkthrough.zip"
    with zipfile.ZipFile(package, "w") as archive:
        script = "android_render_baseline.py" if render_baseline else "android_native_walkthrough.py"
        if visual_probe or visual_gameplay:
            script = "android_visual_profile_probe.py"
            if visual_gameplay:
                archive.write(ROOT / "tools/android_native_walkthrough.py",
                              "tests/android_native_walkthrough.py")
            archive.write(visual_engine, "tools/godot", compress_type=zipfile.ZIP_DEFLATED)
            for name, runtime in visual_runtime.items():
                archive.write(runtime["path"], "tools/runtime/" + name,
                              compress_type=zipfile.ZIP_DEFLATED)
            archive.write(ROOT / "tools/capture_godot_visual_profile.gd",
                          "tools/capture_godot_visual_profile.gd")
        archive.write(ROOT / "tools" / script, "tests/test_walkthrough.py")
        if shader_sources:
            archive.write(ROOT / "tools/android_collect_shader_sources.py",
                          "tools/android_collect_shader_sources.py")
        if not render_baseline:
            archive.write(ROOT / "tools/android_cpu_sample.py",
                          "tests/android_cpu_sample.py")
            archive.write(ROOT / "tools/android_system_trace.py",
                          "tests/android_system_trace.py")
            archive.write(ROOT / "tools/android_present_intervals.py",
                          "tests/android_present_intervals.py")
        if multitouch:
            archive.write(ROOT / "tools/android_multitouch.py", "tests/android_multitouch.py")
            archive.writestr("tools/iron-multitouch.jar", multitouch_jar)
        archive.writestr("requirements.txt", "pytest==9.1.1\n")
        for wheel in (OUT / "wheelhouse").glob("*.whl"):
            archive.write(wheel, "wheelhouse/" + wheel.name)
    spec = OUT / "native-walkthrough.yml"
    spec.write_text("""version: 0.1
android_test_host: amazon_linux_2
phases:
  install:
    commands:
      - devicefarm-cli use python 3.11
  pre_test:
    commands:
      - adb install -r "$DEVICEFARM_APP_PATH"
  test:
    commands:
      - cd "$DEVICEFARM_TEST_PACKAGE_PATH"
      - python tests/test_walkthrough.py
  post_test:
    commands:
      - adb logcat -d > "$DEVICEFARM_LOG_DIR/final.logcat"
artifacts:
  - $DEVICEFARM_LOG_DIR
""".replace('      - adb install -r "$DEVICEFARM_APP_PATH"',
            '      - adb install -r "$DEVICEFARM_APP_PATH"' +
            ('\n      - adb push "$DEVICEFARM_TEST_PACKAGE_PATH/tools/iron-multitouch.jar" '
             '/data/local/tmp/iron-multitouch.jar' if multitouch else "")
            ).replace("python tests/test_walkthrough.py",
            measurement_env + ("ANDROID_PROFILE_GAME=1 " if profile_game else "") +
            "python tests/test_walkthrough.py").replace(
            '      - adb logcat -d > "$DEVICEFARM_LOG_DIR/final.logcat"',
            '      - adb logcat -d > "$DEVICEFARM_LOG_DIR/final.logcat"' +
            ('\n      - python "$DEVICEFARM_TEST_PACKAGE_PATH/tools/android_collect_shader_sources.py"'
             if shader_sources else "")))
    arns = []
    for path, kind in [(package, "APPIUM_PYTHON_TEST_PACKAGE"), (spec, "APPIUM_PYTHON_TEST_SPEC")]:
        upload = client.create_upload(projectArn=prior["project"], name=path.name, type=kind)["upload"]
        httpx.put(upload["url"], content=path.read_bytes(), timeout=120).raise_for_status()
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline:
            state = client.get_upload(arn=upload["arn"])["upload"]
            if state["status"] == "SUCCEEDED":
                break
            if state["status"] == "FAILED":
                raise RuntimeError(state.get("message", "Upload failed"))
            time.sleep(5)
        else:
            raise TimeoutError("Upload processing timed out")
        arns.append(upload["arn"])
    run = client.schedule_run(
        projectArn=prior["project"], appArn=prior["upload"], devicePoolArn=prior["pool"],
        name=("Android-native-visual-support-probe" if visual_probe else
              "Android-native-visual-gameplay" if visual_gameplay else
              "Android-static-render-baseline" if render_baseline else
              "Android-native-section-profile" if profile_game else "Android-latest-native-gameplay"), test={"type": "APPIUM_PYTHON",
            "testPackageArn": arns[0], "testSpecArn": arns[1]},
        executionConfiguration={"jobTimeoutMinutes": 10 if render_baseline else
                                max(10, math.ceil((seconds + warmup_seconds + 400
                                                   + (85 if initial_route_probe else 0)) / 60)),
                                "videoCapture": video_capture, "skipAppResign": True},
    )["run"]
    report = {"run": run["arn"], "apk_sha256": prior["apk_sha256"],
              "shader_sources_collection_requested": shader_sources,
              "ground_material_diagnostic_requested": ground_materials,
              "visual_profile_probe_requested": visual_probe,
              "visual_profile_gameplay_requested": visual_gameplay,
              "visual_collector_sha256": visual_engine_sha256,
              "visual_runtime_sha256": {name: item["sha256"]
                                        for name, item in visual_runtime.items()},
              "visual_probe_seconds": 90 if visual_probe else None,
              "profiling_requested": profile_game, "render_baseline_requested": render_baseline,
              "initial_route_probe_requested": initial_route_probe,
              "building_route_requested": os.environ.get("ANDROID_BUILDING_ROUTE") == "1",
              "multitouch_requested": multitouch,
              "system_trace_requested": system_trace,
              "system_trace_profile": trace_profile if system_trace else None,
              "cpu_sample_requested": cpu_sample,
              "multitouch_jar_sha256": multitouch_sha256,
              "present_seconds": None if render_baseline or visual_probe else seconds,
              "active_warmup_seconds": None if render_baseline or visual_probe else warmup_seconds}
    (OUT / "native-walkthrough-run.json").write_text(json.dumps(report, indent=2))
    print(json.dumps(report))


if __name__ == "__main__":
    main()
