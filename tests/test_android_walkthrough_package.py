"""Offline checks of Device Farm packaging; no AWS or device calls."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import zipfile


ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.out = Path(self.temp.name)
        self.aws = MagicMock()
        self.http = MagicMock()
        self.env = patch.dict(os.environ, {"ANDROID_BUILD_DIR": str(self.out)}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        spec = importlib.util.spec_from_file_location(
            "walkthrough_package", ROOT / "tools/schedule_android_walkthrough.py")
        self.module = importlib.util.module_from_spec(spec)
        with patch.dict("sys.modules", {"boto3": self.aws, "httpx": self.http}):
            spec.loader.exec_module(self.module)
        (self.out / "devicefarm.json").write_text(json.dumps({
            "project": "project", "pool": "pool", "upload": "apk", "apk_sha256": "a" * 64}))
        client = self.aws.client.return_value
        client.create_upload.return_value = {"upload": {"url": "https://example.invalid", "arn": "upload"}}
        client.get_upload.return_value = {"upload": {"status": "SUCCEEDED"}}
        client.schedule_run.return_value = {"run": {"arn": "run"}}

    def enable(self, dex=b"dex\n035\0"):
        jar = self.out / "injector.jar"
        with zipfile.ZipFile(jar, "w") as archive:
            archive.writestr("classes.dex", dex)
        os.environ.update(ANDROID_MULTITOUCH="1", ANDROID_MULTITOUCH_JAR=str(jar))
        return jar

    def test_enabled_packages_exact_jar_and_import_and_push(self):
        jar = self.enable()
        self.module.main()
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertEqual(archive.read("tools/iron-multitouch.jar"), jar.read_bytes())
            self.assertEqual(archive.read("tests/android_multitouch.py"),
                             (ROOT / "tools/android_multitouch.py").read_bytes())
        spec = (self.out / "native-walkthrough.yml").read_text()
        self.assertIn('adb push "$DEVICEFARM_TEST_PACKAGE_PATH/tools/iron-multitouch.jar" '
                      '/data/local/tmp/iron-multitouch.jar', spec)
        self.assertIn("ANDROID_MULTITOUCH=1 python tests/test_walkthrough.py", spec)
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertEqual(report["multitouch_jar_sha256"], hashlib.sha256(jar.read_bytes()).hexdigest())
        self.aws.client.return_value.schedule_run.assert_called_once()

    def test_disabled_does_not_push_or_enable(self):
        self.module.main()
        spec = (self.out / "native-walkthrough.yml").read_text()
        self.assertNotIn("adb push", spec)
        self.assertNotIn("ANDROID_MULTITOUCH=", spec)
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertNotIn("tools/iron-multitouch.jar", archive.namelist())
        self.assertIn("ANDROID_COMBAT_VIEW_DIAGNOSTIC=0", spec)
        self.assertNotIn("android_collect_shader_sources.py", spec)

    def test_shader_sources_collected_after_test_even_if_gameplay_fails(self):
        os.environ["ANDROID_COLLECT_SHADER_SOURCES"] = "1"
        self.module.main()
        spec = (self.out / "native-walkthrough.yml").read_text()
        post = spec.split("  post_test:\n", 1)[1].split("artifacts:", 1)[0]
        self.assertIn('python "$DEVICEFARM_TEST_PACKAGE_PATH/tools/android_collect_shader_sources.py"',
                      post)
        self.assertLess(post.index("adb logcat"), post.index("python"))
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertEqual(archive.read("tools/android_collect_shader_sources.py"),
                             (ROOT / "tools/android_collect_shader_sources.py").read_bytes())
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertTrue(report["shader_sources_collection_requested"])

    def test_live_visual_diagnostic_flag_reaches_device(self):
        os.environ["ANDROID_COMBAT_VIEW_DIAGNOSTIC"] = "1"
        self.module.main()
        spec = (self.out / "native-walkthrough.yml").read_text()
        self.assertIn("ANDROID_COMBAT_VIEW_DIAGNOSTIC=1", spec)

    def test_ground_material_flag_reaches_device(self):
        os.environ.update(ANDROID_GROUND_MATERIAL_DIAGNOSTIC="1",
                          ANDROID_PROFILE_GAME="1")
        self.module.main()
        self.assertIn("ANDROID_GROUND_MATERIAL_DIAGNOSTIC=1",
                      (self.out / "native-walkthrough.yml").read_text())
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertTrue(report["ground_material_diagnostic_requested"])

    def test_ground_material_requires_gameplay_before_aws(self):
        os.environ["ANDROID_GROUND_MATERIAL_DIAGNOSTIC"] = "1"
        with self.assertRaisesRegex(ValueError, "requires gameplay"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_trace_flag_and_helper_reach_device(self):
        os.environ["ANDROID_SYSTEM_TRACE"] = "1"
        self.module.main()
        self.assertIn("ANDROID_SYSTEM_TRACE=1",
                      (self.out / "native-walkthrough.yml").read_text())
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertEqual(archive.read("tests/android_system_trace.py"),
                             (ROOT / "tools/android_system_trace.py").read_bytes())

    def test_missing_jar_rejects_before_aws(self):
        os.environ["ANDROID_MULTITOUCH"] = "1"
        with self.assertRaisesRegex(ValueError, "ANDROID_MULTITOUCH_JAR"):
            self.module.main()
        self.aws.client.assert_not_called()

    def enable_visual_probe(self):
        binary = self.out / "godot"
        binary.write_bytes(b"\x7fELF\x02\x01" + bytes(12) + b"\x3e\x00")
        runtime = self.out / "runtime"
        runtime.mkdir()
        names = ("ld-linux-x86-64.so.2", "libc.so.6", "libm.so.6",
                 "libpthread.so.0", "libdl.so.2", "librt.so.1")
        for name in names:
            (runtime / name).write_bytes(name.encode())
        os.environ.update(ANDROID_VISUAL_PROFILE_PROBE="1",
                          ANDROID_VISUAL_PROFILE_GODOT=str(binary),
                          ANDROID_VISUAL_PROFILE_RUNTIME=str(runtime))
        return binary, names

    def test_visual_probe_bundles_collector_and_records_hash(self):
        binary, names = self.enable_visual_probe()
        self.module.main()
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertEqual(archive.read("tools/godot"), binary.read_bytes())
            self.assertEqual(archive.read("tests/test_walkthrough.py"),
                             (ROOT / "tools/android_visual_profile_probe.py").read_bytes())
            self.assertIn("tools/capture_godot_visual_profile.gd", archive.namelist())
            for name in names:
                self.assertEqual(archive.read("tools/runtime/" + name), name.encode())
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertEqual(report["visual_collector_sha256"],
                         hashlib.sha256(binary.read_bytes()).hexdigest())
        self.assertTrue(report["visual_profile_probe_requested"])
        self.assertIsNone(report["present_seconds"])
        self.assertIsNone(report["active_warmup_seconds"])
        self.assertEqual(report["visual_runtime_sha256"],
                         {name: hashlib.sha256(name.encode()).hexdigest() for name in names})

    def test_visual_gameplay_bundles_touch_child_and_preserves_duration(self):
        self.enable_visual_probe()
        self.enable()
        os.environ.update(ANDROID_VISUAL_PROFILE_PROBE="0",
                          ANDROID_VISUAL_PROFILE_GAMEPLAY="1", ANDROID_PROFILE_GAME="1",
                          ANDROID_PRESENT_SECONDS="25", ANDROID_ACTIVE_WARMUP_SECONDS="0")
        self.module.main()
        with zipfile.ZipFile(self.out / "native-walkthrough.zip") as archive:
            self.assertEqual(archive.read("tests/android_native_walkthrough.py"),
                             (ROOT / "tools/android_native_walkthrough.py").read_bytes())
            self.assertIn("tests/android_multitouch.py", archive.namelist())
            self.assertIn("tools/godot", archive.namelist())
        spec = (self.out / "native-walkthrough.yml").read_text()
        self.assertIn("ANDROID_VISUAL_PROFILE_GAMEPLAY=1 ANDROID_PROFILE_GAME=1", spec)
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertTrue(report["visual_profile_gameplay_requested"])
        self.assertFalse(report["visual_profile_probe_requested"])
        self.assertEqual(report["present_seconds"], 25)
        self.assertEqual(report["active_warmup_seconds"], 0)

    def test_visual_gameplay_requires_profile_game_before_aws(self):
        os.environ["ANDROID_VISUAL_PROFILE_GAMEPLAY"] = "1"
        with self.assertRaisesRegex(ValueError, "requires profile-game"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_visual_probe_conflict_rejected_before_aws(self):
        os.environ.update(ANDROID_VISUAL_PROFILE_PROBE="1", ANDROID_SYSTEM_TRACE="1")
        with self.assertRaisesRegex(ValueError, "must run alone"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_visual_probe_wrong_host_binary_rejected_before_aws(self):
        binary = self.out / "godot"
        binary.write_bytes(b"not an ELF")
        os.environ.update(ANDROID_VISUAL_PROFILE_PROBE="1",
                          ANDROID_VISUAL_PROFILE_GODOT=str(binary))
        with self.assertRaisesRegex(ValueError, "x86_64"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_render_trace_profile_reaches_device_and_record(self):
        os.environ.update(ANDROID_SYSTEM_TRACE="1", ANDROID_SYSTEM_TRACE_PROFILE="render")
        self.module.main()
        self.assertIn("ANDROID_SYSTEM_TRACE_PROFILE=render",
                      (self.out / "native-walkthrough.yml").read_text())
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertEqual(report["system_trace_profile"], "render")

    def test_invalid_trace_profile_rejects_before_aws(self):
        os.environ["ANDROID_SYSTEM_TRACE_PROFILE"] = "render;bad"
        with self.assertRaisesRegex(ValueError, "ANDROID_SYSTEM_TRACE_PROFILE"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_joint_trace_profile_reaches_device_and_record(self):
        os.environ.update(ANDROID_SYSTEM_TRACE="1", ANDROID_SYSTEM_TRACE_PROFILE="joint")
        self.module.main()
        self.assertIn("ANDROID_SYSTEM_TRACE_PROFILE=joint",
                      (self.out / "native-walkthrough.yml").read_text())
        report = json.loads((self.out / "native-walkthrough-run.json").read_text())
        self.assertEqual(report["system_trace_profile"], "joint")

    def test_invalid_dex_rejects_before_aws(self):
        self.enable(b"not dex")
        with self.assertRaisesRegex(ValueError, "classes.dex"):
            self.module.main()
        self.aws.client.assert_not_called()

    def test_static_baseline_rejects_before_aws(self):
        self.enable()
        os.environ["ANDROID_RENDER_BASELINE"] = "1"
        with self.assertRaisesRegex(ValueError, "native walkthrough"):
            self.module.main()
        self.aws.client.assert_not_called()


if __name__ == "__main__":
    unittest.main()
