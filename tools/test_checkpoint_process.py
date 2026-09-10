"""Separate Godot processes suspend and resume one offline operation twice."""
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
location = ROOT / "artifacts" / ("checkpoint-process-" + str(time.time_ns()))
location.mkdir()
env = dict(os.environ, CHECKPOINT_TEST_DIR=str(location))
if "--packed" in sys.argv:
    command = [str(ROOT / "artifacts/IronMeridian-Linux/play.sh"), "--headless"]
else:
    command = [str(ROOT / "tools/godot"), "--headless", "--path", str(ROOT / "client")]
command += ["--script", str(ROOT / "tests/checkpoint_process.gd")]
ids = []
for index, mode in enumerate(["--write-checkpoint", "--read-checkpoint", "--read-checkpoint"]):
    result = subprocess.run(command + ["--", mode], env=env, cwd=ROOT, capture_output=True, text=True, timeout=20)
    text = result.stdout + result.stderr
    (location / f"process-{index}.log").write_text(text)
    assert result.returncode == 0 and "_PASS id=" in text, text
    assert not any(error in text for error in ("SCRIPT ERROR", "Assertion failed", "ObjectDB instances leaked")), text
    ids.append(re.search(r"_PASS id=([0-9a-f-]+)", text).group(1))
assert len(set(ids)) == 1
print("CHECKPOINT_PROCESS_PASS independent_processes=3 same_round=ok stock_timers=ok no_abandoned_results=ok")
