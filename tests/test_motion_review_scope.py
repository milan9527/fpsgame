"""Ensure partial weapon coverage cannot be reported as full motion coverage."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_weapon_motion_review import audit_capture


class MotionScopeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        inputs = {}
        for name in ("executable", "pack", "script"):
            path = self.base / name
            path.write_text(name)
            inputs[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.scope = ["first-weapon-2"]
        self.status = dict(status="exited", exit_code=0,
                           requested_clips=self.scope, inputs_sha256=inputs)
        samples = []
        for frame in range(0, 193, 6):
            name = f"first-weapon-2-frame-{frame:04d}"
            Image.new("RGB", (1, 1)).save(self.base / f"{name}.png")
            samples.append(dict(name=name, clip_frame=frame,
                                reload_left=1 if frame < 192 else 0))
        self.capture = dict(complete=True, world_visible=True, viewport=[1, 1],
                            requested_clips=self.scope, samples=samples)
        (self.base / "capture.log").write_text("WEAPON_MOTION_REVIEW_PASS\n")

    def audit(self):
        (self.base / "process-result.json").write_text(json.dumps(self.status))
        (self.base / "motion-review.json").write_text(json.dumps(self.capture))
        return audit_capture(self.base)

    def test_subset_pass_is_not_full_suite_pass(self):
        result = self.audit()
        self.assertTrue(result["passed"], result["errors"])
        self.assertFalse(result["full_suite_passed"])

    def test_missing_middle_sample_fails(self):
        self.capture["samples"].pop(10)
        self.assertFalse(self.audit()["passed"])

    def test_scope_disagreement_fails(self):
        self.capture["requested_clips"] = ["first-weapon-1"]
        self.assertFalse(self.audit()["passed"])

    def test_interrupted_process_cannot_pass(self):
        self.status["exit_code"] = -15
        self.assertFalse(self.audit()["passed"])


if __name__ == "__main__":
    unittest.main()
