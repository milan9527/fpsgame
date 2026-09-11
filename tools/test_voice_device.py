"""Exercise Godot's real PulseAudio input driver with an isolated synthetic source."""
import argparse
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import time
import wave
from candidate_runtime import candidate_command

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pulse-root", type=Path, default=ROOT / "artifacts/voice-pulse-runtime")
    parser.add_argument("--candidate-dir", type=Path)
    args = parser.parse_args()
    runtime = [str(ROOT / "tools/godot"), "--path", str(ROOT / "client")]
    candidate = None
    if args.candidate_dir:
        packed, candidate = candidate_command(args.candidate_dir)
        runtime = packed[:-1]
    log_prefix = "candidate-voice-device" if candidate else "voice-device"
    pulse_root = args.pulse_root.resolve()
    daemon = pulse_root / "usr/bin/pulseaudio"
    if not daemon.exists():
        raise SystemExit("Extract the pulseaudio RPM into --pulse-root; see docs/VOICE.md.")
    for tool in ("pactl", "paplay"):
        if not shutil.which(tool):
            raise SystemExit(f"Missing {tool}; install pulseaudio-utils.")
    processes = []
    with tempfile.TemporaryDirectory(prefix="iron-voice-") as directory:
        work = Path(directory)
        env = os.environ.copy()
        env.update({
            "PULSE_SERVER": f"unix:{work}/native",
            "PULSE_SOURCE": "fixture.monitor",
            "PULSE_SINK": "game_output",
            "PULSE_RUNTIME_PATH": str(work),
            "PULSE_STATE_PATH": str(work / "state"),
            "XDG_RUNTIME_DIR": str(work),
            "VOICE_VIRTUAL_DEVICE_TEST": "1",
            "LD_LIBRARY_PATH": ":".join(str(pulse_root / subdir) for subdir in (
                "usr/lib64/pulseaudio", "usr/lib64/pulse-15.0/modules")),
        })
        config = work / "pulse.pa"
        config.write_text(
            f"load-module module-native-protocol-unix socket={work}/native auth-anonymous=1\n"
            "load-module module-null-sink sink_name=fixture rate=48000 channels=2\n"
            "load-module module-null-sink sink_name=game_output rate=48000 channels=2\n"
            "set-default-sink game_output\nset-default-source fixture.monitor\n"
        )
        # Only generated samples are ever routed into the microphone fixture.
        with wave.open(str(work / "tone.wav"), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(48000)
            second = b"".join(
                struct.pack("<hh", *([round(8192 * math.sin(2 * math.pi * 440 * i / 48000))] * 2))
                for i in range(48000)
            )
            output.writeframes(second * 30)
        with (ROOT / "artifacts" / (log_prefix + "-daemon.log")).open("w") as daemon_log:
            try:
                processes.append(subprocess.Popen([
                    str(daemon), "-n", "--daemonize=no", "--use-pid-file=no",
                    "--exit-idle-time=-1", "--disallow-exit=yes",
                    "--dl-search-path=" + str(pulse_root / "usr/lib64/pulse-15.0/modules"),
                    "--file=" + str(config),
                ], env=env, stdout=daemon_log, stderr=subprocess.STDOUT))
                deadline = time.monotonic() + 5
                while True:
                    if processes[0].poll() is not None:
                        raise RuntimeError(f"Private audio server exited; inspect {log_prefix}-daemon.log")
                    probe = subprocess.run(["pactl", "info"], env=env, capture_output=True, timeout=2)
                    if probe.returncode == 0:
                        break
                    if time.monotonic() >= deadline:
                        raise RuntimeError("Private audio server did not become ready")
                    time.sleep(0.1)
                processes.append(subprocess.Popen([
                    "paplay", "--latency-msec=20", "--device=fixture", str(work / "tone.wav")
                ], env=env, stdout=subprocess.DEVNULL, stderr=daemon_log))
                output_path = ROOT / "artifacts" / (log_prefix + "-driver.log")
                with output_path.open("w") as output:
                    result = subprocess.run(runtime + [
                        "--display-driver", "headless", "--audio-driver", "PulseAudio",
                        "--script", str(ROOT / "tests/voice_device.gd"),
                    ], env=env, stdout=output, stderr=subprocess.STDOUT, timeout=20)
                text = output_path.read_text()
                print(text, end="")
                assert result.returncode == 0 and "VOICE_DEVICE_PASS" in text
                assert not any(error in text for error in ("SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked"))
                assert processes[0].poll() is None and processes[1].poll() is None
            finally:
                for process in reversed(processes):
                    if process.poll() is None:
                        process.terminate()
                        try:
                            process.wait(timeout=3)
                        except subprocess.TimeoutExpired:
                            process.kill()
                            process.wait(timeout=3)
    print("VOICE_VIRTUAL_DRIVER_PASS isolated_server=ok synthetic_source=ok processes_cleaned=ok")
    if candidate:
        print("CANDIDATE_VOICE_DRIVER_PASS commit=" + candidate["commit"] + " archive_sha256=" + candidate["sha256"])


if __name__ == "__main__":
    main()
