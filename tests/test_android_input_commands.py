"""Host command logging tests; not evidence of actual device input delivery."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parents[1] / "tools"
with patch.dict(os.environ, {"DEVICEFARM_LOG_DIR": "/unused"}), \
        patch.object(sys, "path", [str(TOOLS), *sys.path]):
    spec = importlib.util.spec_from_file_location(
        "walkthrough", TOOLS / "android_native_walkthrough.py")
    walkthrough = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(walkthrough)


class InputCommandsTest(unittest.TestCase):
    def test_command_success_failure_and_non_input(self):
        with tempfile.TemporaryDirectory() as tmp, \
                patch.object(walkthrough, "OUT", Path(tmp)), \
                patch.object(walkthrough.subprocess, "check_output") as command:
            command.return_value = b"ok"
            self.assertEqual(walkthrough.adb("shell", "input", "tap", "1", "2"), b"ok")
            command.side_effect = subprocess.CalledProcessError(1, ["adb"])
            with self.assertRaises(subprocess.CalledProcessError):
                walkthrough.adb("shell", "input", "swipe", "1", "2", "3", "4", "300")
            command.side_effect = None
            walkthrough.adb("logcat", "-d")
            events = [json.loads(line) for line in
                      (Path(tmp) / "input-commands.jsonl").read_text().splitlines()]
            self.assertEqual(len(events), 2)
            self.assertEqual([event["success"] for event in events], [True, False])
            self.assertEqual(events[0]["command"], ["shell", "input", "tap", "1", "2"])
            for event in events:
                self.assertLessEqual(event["host_start_monotonic_s"],
                                     event["host_end_monotonic_s"])


if __name__ == "__main__":
    unittest.main()
