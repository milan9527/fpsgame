#!/usr/bin/env python3
"""Recompute the background goal's Android frame-time acceptance gate."""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def artifact(name):
    path = (ROOT / name).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file() or not path.stat().st_size:
        raise ValueError(f"Missing/non-project evidence: {name}")
    return path


def check(report):
    apk = artifact(report["apk_path"])
    hasher = hashlib.sha256()
    with apk.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(chunk)
    digest = hasher.hexdigest()
    if digest != report["apk_sha256"]:
        raise ValueError("APK digest mismatch")
    artifact(report["visual_review_path"])
    artifact(report["functional_review_path"])
    counts = {"solo": 0, "online": 0}
    seen = set()
    metrics = []
    for run in report["runs"]:
        mode = run["mode"]
        if mode not in counts or not run["device"].strip():
            raise ValueError("Expected named device and solo/online mode")
        artifact(run["gameplay_evidence_path"])
        path = artifact(run["frame_times_path"])
        content = path.read_bytes()
        fingerprint = hashlib.sha256(content).hexdigest()
        if fingerprint in seen:
            raise ValueError("Duplicated frame evidence")
        seen.add(fingerprint)
        values = json.loads(content)
        if isinstance(values, dict):
            values = values["frame_times_ms"]
        if not isinstance(values, list) or not values:
            raise ValueError("Expected raw frame-time array")
        if any(type(v) not in (int, float) or not math.isfinite(v) or v <= 0 for v in values):
            raise ValueError("Invalid frame intervals")
        duration = sum(values) / 1000
        ordered = sorted(values)
        fps = len(values) / duration
        p95 = ordered[math.ceil(len(values) * .95) - 1]
        p99 = ordered[math.ceil(len(values) * .99) - 1]
        slow = sum(v > 50 for v in values) / len(values)
        if duration < 300 or fps < 58 or p95 > 20 or p99 > 33.4 or slow > .01:
            raise ValueError(f"Performance failed: {mode} {duration=:.1f} {fps=:.2f} {p95=} {p99=} {slow=}")
        counts[mode] += 1
        metrics.append(dict(mode=mode, device=run["device"], duration_s=duration,
                            fps=fps, p95_ms=p95, p99_ms=p99, over_50ms_ratio=slow))
    if min(counts.values()) < 3:
        raise ValueError("Need at least three independent runs per mode")
    return metrics


if __name__ == "__main__":
    try:
        report = json.loads(artifact("artifacts/background-goal/android-acceptance.json").read_text())
        print(json.dumps({"passed": True, "metrics": check(report)}, ensure_ascii=False))
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(json.dumps({"passed": False, "error": str(exc)}, ensure_ascii=False))
        raise SystemExit(1)
