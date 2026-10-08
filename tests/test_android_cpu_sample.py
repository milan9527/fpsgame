"""Profiler lifecycle regression checks; mocks are not performance evidence."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "cpu_sample", Path(__file__).resolve().parents[1] / "tools/android_cpu_sample.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CpuSampleTests(unittest.TestCase):
    def test_disabled_never_starts_device_commands(self):
        with patch.dict(os.environ, {"ANDROID_CPU_SAMPLE": "0"}), \
                patch.object(module.subprocess, "run") as run, \
                patch.object(module.subprocess, "Popen") as start:
            with module.cpu_sample(Path("/unused"), "game"):
                pass
            run.assert_not_called()
            start.assert_not_called()

    def exercise(self, folder, process, *, unavailable=False, gameplay_error=False):
        def run(command, **kwargs):
            if "--version" in command:
                if unavailable:
                    raise subprocess.CalledProcessError(127, command)
                return subprocess.CompletedProcess(command, 0, b"simpleperf")
            if "pidof" in command:
                return subprocess.CompletedProcess(command, 0, b"1234\n")
            if "pull" in command:
                Path(command[-1]).write_bytes(b"synthetic-profile")
            return subprocess.CompletedProcess(command, 0, b"")

        with patch.dict(os.environ, {"ANDROID_CPU_SAMPLE": "1"}), \
                patch.object(module.subprocess, "run", side_effect=run) as commands, \
                patch.object(module.subprocess, "Popen", return_value=process) as start:
            if gameplay_error:
                with self.assertRaisesRegex(RuntimeError, "gameplay failed"):
                    with module.cpu_sample(Path(folder), "game"):
                        raise RuntimeError("gameplay failed")
            else:
                with module.cpu_sample(Path(folder), "game"):
                    pass
            report = json.loads((Path(folder) / "cpu-sample-status.json").read_text())
            self.assertFalse(report["acceptance"])
            return report, commands, start

    def test_unavailable_profiler_preserves_gameplay_exception(self):
        with tempfile.TemporaryDirectory() as folder:
            report, commands, start = self.exercise(
                folder, Mock(), unavailable=True, gameplay_error=True)
            self.assertIn("start_error", report)
            self.assertEqual(commands.call_count, 1)
            start.assert_not_called()

    def test_gameplay_failure_still_collects_and_removes_remote_data(self):
        with tempfile.TemporaryDirectory() as folder:
            process = Mock(returncode=0)
            process.wait.return_value = 0
            report, commands, start = self.exercise(folder, process, gameplay_error=True)
            self.assertEqual(report["data_bytes"], len(b"synthetic-profile"))
            self.assertEqual(commands.call_args.args[0][2:4], ["rm", "-f"])
            command = start.call_args.args[0]
            self.assertEqual(command[command.index("-e") + 1], "cpu-clock:u")
            self.assertEqual(report["event"], "cpu-clock:u")
            self.assertEqual(command[command.index("--duration") + 1], "35")
            self.assertEqual(command[command.index("-f") + 1], "99")

    def test_record_failure_is_not_reported_as_success(self):
        with tempfile.TemporaryDirectory() as folder:
            process = Mock(returncode=1)
            process.wait.return_value = 1
            report, commands, _ = self.exercise(folder, process)
            self.assertIn("sampling_error", report)
            self.assertNotIn("data_bytes", report)
            self.assertFalse(any("pull" in call.args[0] for call in commands.call_args_list))
            self.assertEqual(commands.call_args.args[0][2:4], ["rm", "-f"])

    def test_timeout_kills_host_process_and_preserves_gameplay_exception(self):
        with tempfile.TemporaryDirectory() as folder:
            process = Mock(returncode=None)
            process.wait.side_effect = [subprocess.TimeoutExpired("adb", 45), 0]
            process.poll.return_value = None
            report, commands, _ = self.exercise(folder, process, gameplay_error=True)
            process.kill.assert_called_once()
            self.assertIn("collection_error", report)
            self.assertEqual(commands.call_args.args[0][2:4], ["rm", "-f"])


if __name__ == "__main__":
    unittest.main()
