"""Regression cases for interrupted or stale engine capture evidence."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_weapon_motion_review import audit_capture


class EvidenceAuditTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        inputs = {}
        for name in ("preview", "preview.pck", "capture.gd"):
            path = self.base / name
            path.write_bytes(name.encode())
            inputs[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.status = {"status": "exited", "exit_code": 0, "inputs_sha256": inputs}
        # Valid 1x1 PNG, used solely as an evidence fixture.
        import base64
        png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
        samples = []
        for view in ("first", "third-stand", "third-crouch"):
            for weapon, end in enumerate((132, 180, 192)):
                for frame in range(0, end + 1, 6):
                    name = f"{view}-weapon-{weapon}-frame-{frame:03d}"
                    samples.append({"name": name, "clip_frame": frame,
                                    "reload_left": max(0, (end - 12 - frame) / 60)})
                    (self.base / f"{name}.png").write_bytes(png)
        self.capture = {"complete": True, "world_visible": True, "viewport": [1, 1], "samples": samples}
        (self.base / "capture.log").write_text("WEAPON_MOTION_REVIEW_PASS\n")
        self.save()

    def save(self):
        (self.base / "process-result.json").write_text(json.dumps(self.status))
        (self.base / "motion-review.json").write_text(json.dumps(self.capture))

    def test_complete(self):
        self.assertTrue(audit_capture(self.base)["passed"])

    def test_orphan_exit_never_inferred(self):
        self.status = dict(self.status, status="running")
        self.status.pop("exit_code")
        self.save()
        result = audit_capture(self.base)
        self.assertTrue(result["evidence_complete"])
        self.assertFalse(result["passed"])
        self.assertIsNone(result["recorded_exit_code"])

    def test_missing_middle_frame(self):
        self.capture["samples"].pop(4)
        self.save()
        self.assertFalse(audit_capture(self.base)["passed"])

    def test_missing_post_reload_hold(self):
        self.capture["samples"].pop(22)
        self.save()
        self.assertFalse(audit_capture(self.base)["passed"])

    def test_stale_pck(self):
        (self.base / "preview.pck").write_bytes(b"changed")
        self.assertFalse(audit_capture(self.base)["passed"])

    def test_truncated_image(self):
        path = self.base / (self.capture["samples"][0]["name"] + ".png")
        path.write_bytes(path.read_bytes()[:-12])
        self.assertFalse(audit_capture(self.base)["passed"])

    def test_engine_error_after_marker(self):
        with (self.base / "capture.log").open("a") as log:
            log.write("SCRIPT ERROR: reload assertion\n")
        self.assertFalse(audit_capture(self.base)["passed"])

    def test_partial_manifest_not_final(self):
        (self.base / "motion-review.json").rename(self.base / "contact-review.partial.json")
        self.assertFalse(audit_capture(self.base)["passed"])


if __name__ == "__main__":
    unittest.main()
