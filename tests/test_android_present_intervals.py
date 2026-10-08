"""Synthetic parser tests only; these are not device acceptance evidence."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from threading import Event
import json
import shlex

spec = importlib.util.spec_from_file_location(
    "present", Path(__file__).resolve().parents[1] / "tools/android_present_intervals.py")
present = importlib.util.module_from_spec(spec)
spec.loader.exec_module(present)


class PresentIntervalsTest(unittest.TestCase):
    def test_stopped_diagnostic_retains_raw_and_never_claims_valid(self):
        stop = Event()
        def response(*args, **kwargs):
            stop.set()
            return SimpleNamespace(stdout="16666666\n1 200000000 1\n",
                                   stderr="", returncode=0, check_returncode=lambda: None)
        with TemporaryDirectory() as tmp, patch.object(
                present.subprocess, "run", side_effect=response):
            output = Path(tmp) / "intervals"
            with self.assertRaisesRegex(ValueError, "stopped"):
                present.collect("game", output, 300, .5, stop=stop)
            self.assertEqual(json.loads((output / "timestamps.json").read_text()),
                             [200000000])
            self.assertFalse(json.loads((output / "collection.json").read_text())["valid"])
            self.assertFalse((output / "frame-times.json").exists())

    def test_android17_wrapped_layer_names(self):
        package = "org.ironmeridian.game"
        layer = f"cf7c568 SurfaceView[{package}/com.godot.game.GodotApp](BLAST)#763"
        listing = (f"RequestedLayerState{{{layer} parentId=762}}\n"
                   f"RequestedLayerState{{{layer} parentId=762 relativeParentId=759 z=-2}}\n"
                   f"{layer}\nSurfaceView[other/App]#1\n")
        self.assertEqual(present.surface_layers(listing, package), [layer])
        self.assertEqual(shlex.split(present.latency_command(layer)[2])[-1], layer)

    def test_layer_survives_remote_shell(self):
        layer = "SurfaceView[org.ironmeridian.game/App](BLAST)#45"
        command = present.latency_command(layer)
        self.assertEqual(command[:2], ["adb", "shell"])
        self.assertEqual(shlex.split(command[2]),
                         ["dumpsys", "SurfaceFlinger", "--latency", layer])

    def test_probe_empty_layers_retains_failure(self):
        response = SimpleNamespace(stdout="other layer\n", stderr="", returncode=0,
                                   check_returncode=lambda: None)
        with TemporaryDirectory() as tmp, patch.object(
                present.subprocess, "run", return_value=response):
            output = Path(tmp) / "probe"
            report = present.probe("org.ironmeridian.game", output)
            self.assertFalse(report["valid"])
            self.assertTrue((output / "layers.json").exists())
            self.assertIn("found 0", json.loads(
                (output / "probe.json").read_text())["error"])

    def test_actual_column_and_pending_frames(self):
        self.assertEqual(present.actual_present_times(
            "16666666\n1 200 3\n2 300 4\n0 0 0\n1 9223372036854775807 4\n"),
            [200, 300])

    def test_overlap_preserves_long_frames(self):
        timeline = present.Timeline()
        timeline.append([100])
        timeline.append([50, 100, 200])
        timeline.append([100, 200, 100000200])
        self.assertEqual(timeline.timestamps, [100, 200, 100000200])
        timeline.append([100, 200, 100000200])
        self.assertEqual(len(timeline.timestamps), 3)

    def test_missing_ring_overlap_fails(self):
        timeline = present.Timeline()
        timeline.append([100, 200])
        with self.assertRaises(ValueError):
            timeline.append([300, 400])

    def test_collection_excludes_history_and_keeps_long_frame(self):
        ready = Event()
        responses = [
            "16666666\n1 100000000 1\n1 200000000 1\n",
            "16666666\n1 200000000 1\n1 216000000 1\n1 300000000 1\n",
        ]
        def response(*args, **kwargs):
            self.assertEqual(ready.is_set(), len(responses) == 1)
            return SimpleNamespace(stdout=responses.pop(0), stderr="",
                                   returncode=0, check_returncode=lambda: None)
        with TemporaryDirectory() as tmp, patch.object(
                present.subprocess, "run", side_effect=response), patch.object(
                present.time, "sleep"):
            output = Path(tmp) / "intervals"
            present.collect("game", output, .1, .5, ready=ready)
            self.assertTrue(ready.is_set())
            self.assertEqual(json.loads((output / "frame-times.json").read_text()),
                             {"frame_times_ms": [16.0, 84.0]})
            self.assertTrue(json.loads((output / "collection.json").read_text())["valid"])
            self.assertEqual(len(list(output.glob("poll-*.json"))), 2)

    def test_collection_lost_ring_retains_raw_failure(self):
        responses = ["16666666\n1 100 1\n", "16666666\n1 300 1\n"]
        def response(*args, **kwargs):
            return SimpleNamespace(stdout=responses.pop(0), stderr="",
                                   returncode=0, check_returncode=lambda: None)
        with TemporaryDirectory() as tmp, patch.object(
                present.subprocess, "run", side_effect=response), patch.object(
                present.time, "sleep"):
            output = Path(tmp) / "intervals"
            with self.assertRaisesRegex(ValueError, "continuity lost"):
                present.collect("game", output, 300, .5)
            self.assertFalse((output / "frame-times.json").exists())
            self.assertEqual(json.loads((output / "timestamps.json").read_text()), [100])
            self.assertFalse(json.loads((output / "collection.json").read_text())["valid"])
            self.assertEqual(len(list(output.glob("poll-*.json"))), 2)

    def test_unsupported_and_reordered_data_fail(self):
        with self.assertRaises(ValueError):
            present.Timeline().append([])
        with self.assertRaises(ValueError):
            present.actual_present_times("16666666\n1 300 1\n1 200 1\n")


if __name__ == "__main__":
    unittest.main()
