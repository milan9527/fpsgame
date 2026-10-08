import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, call, patch
import tempfile

spec = importlib.util.spec_from_file_location(
    "baseline", Path(__file__).resolve().parents[1] / "tools/android_render_baseline.py")
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class BaselineEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.lines = [
            f"I godot: ANDROID_BASELINE mode={mode} view={view} fps=42 p95_ms=35 "
            f"draws=0 primitives=0 scale={scale}"
            for view, mode, scale in baseline.EXPECTED
        ]
        self.lines.append("I godot: ANDROID_BASELINE_COMPLETE")

    def test_complete_experiment(self):
        self.assertEqual(len(baseline.parse_results("\n".join(self.lines))), 32)

    def test_missing_reordered_or_duplicate_cases(self):
        for lines in (self.lines[1:], self.lines[:-1],
                      [self.lines[1], self.lines[0], *self.lines[2:]],
                      [self.lines[0], *self.lines]):
            with self.subTest(lines=lines), self.assertRaises(ValueError):
                baseline.parse_results("\n".join(lines))

    def test_invalid_measurement_or_runtime_failure(self):
        valid = "\n".join(self.lines)
        for logs in (valid.replace("fps=42", "fps=nan", 1),
                     valid.replace("p95_ms=35", "p95_ms=0", 1),
                     valid + "\nSCRIPT ERROR: invalid access"):
            with self.subTest(logs=logs), self.assertRaises(ValueError):
                baseline.parse_results(logs)

    def test_continuous_capture_preserves_early_cases(self):
        with tempfile.TemporaryDirectory() as directory:
            def start_collector(command, stdout, stderr):
                self.assertEqual(command, ["adb", "logcat"])
                # Simulate enough intervening system output to evict early
                # measurements from the device's ring buffer.
                stdout.write(("\n".join(self.lines[:2]) + "\n").encode())
                stdout.write(b"I unrelated system output\n" * 50000)
                stdout.write(("\n".join(self.lines[2:]) + "\n").encode())
                stdout.flush()
                return collector

            collector = Mock()
            collector.poll.return_value = None
            with patch.dict(baseline.os.environ, {"DEVICEFARM_LOG_DIR": directory}), \
                    patch.object(baseline.subprocess, "Popen", side_effect=start_collector), \
                    patch.object(baseline, "adb", return_value=b"1234") as adb:
                baseline.main()
            logs = (Path(directory) / "render-baseline.logcat").read_text()
            self.assertEqual(len(baseline.parse_results(logs)), 32)
            self.assertNotIn(call("logcat", "-d"), adb.call_args_list)
            collector.terminate.assert_called_once()
            collector.wait.assert_called_once_with(timeout=10)

    def test_launch_failure_preserves_raw_log_and_stops_collector(self):
        with tempfile.TemporaryDirectory() as directory:
            collector = Mock()
            collector.poll.return_value = None

            def start_collector(command, stdout, stderr):
                stdout.write(b"raw startup evidence\n")
                stdout.flush()
                return collector

            with patch.dict(baseline.os.environ, {"DEVICEFARM_LOG_DIR": directory}), \
                    patch.object(baseline.subprocess, "Popen", side_effect=start_collector), \
                    patch.object(baseline, "adb", side_effect=[b"", b"", RuntimeError("launch")]):
                with self.assertRaisesRegex(RuntimeError, "launch"):
                    baseline.main()
            self.assertEqual((Path(directory) / "render-baseline.logcat").read_bytes(),
                             b"raw startup evidence\n")
            collector.terminate.assert_called_once()

    def test_collector_disconnect_cannot_produce_success(self):
        with tempfile.TemporaryDirectory() as directory:
            collector = Mock()
            collector.poll.return_value = 1
            with patch.dict(baseline.os.environ, {"DEVICEFARM_LOG_DIR": directory}), \
                    patch.object(baseline.subprocess, "Popen", return_value=collector), \
                    patch.object(baseline, "adb", return_value=b""):
                with self.assertRaisesRegex(RuntimeError, "collector exited"):
                    baseline.main()
            self.assertFalse((Path(directory) / "render-baseline.json").exists())


if __name__ == "__main__":
    unittest.main()
