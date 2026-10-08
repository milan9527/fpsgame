"""Run the signed APK on one available Android phone; collect native smoke evidence."""
import hashlib
import json
import os
from pathlib import Path
import time

import boto3
import httpx

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("ANDROID_BUILD_DIR", str(ROOT / "artifacts/android-build"))).resolve()


def main():
    build = json.loads((OUT / "build.json").read_text())
    apk = Path(build["apk"])
    assert hashlib.sha256(apk.read_bytes()).hexdigest() == build["sha256"]
    client = boto3.client("devicefarm", region_name="us-west-2")
    devices = [d for page in client.get_paginator("list_devices").paginate(
        filters=[{"attribute": "PLATFORM", "operator": "EQUALS", "values": ["ANDROID"]}])
        for d in page["devices"] if d.get("availability") in {"AVAILABLE", "HIGHLY_AVAILABLE"}]
    assert devices, "No Android devices currently available"
    devices.sort(key=lambda d: ("Pixel" not in d["name"], d["name"]))
    project = client.create_project(name="IronMeridian-Android", defaultJobTimeoutMinutes=15)["project"]["arn"]
    pool = client.create_device_pool(projectArn=project, name="Android-release-validation", rules=[
        {"attribute": "ARN", "operator": "IN", "value": json.dumps([devices[0]["arn"]])}])["devicePool"]["arn"]
    upload = client.create_upload(projectArn=project, name=apk.name, type="ANDROID_APP")["upload"]
    with apk.open("rb") as stream:
        httpx.put(upload["url"], content=stream, timeout=180).raise_for_status()
    deadline = time.monotonic() + 600
    while time.monotonic() < deadline:
        status = client.get_upload(arn=upload["arn"])["upload"]["status"]
        if status == "SUCCEEDED":
            break
        if status == "FAILED":
            raise RuntimeError("Device Farm APK validation failed")
        time.sleep(5)
    else:
        raise TimeoutError("APK processing timeout")
    run = client.schedule_run(projectArn=project, appArn=upload["arn"], devicePoolArn=pool,
        name="Android-native-release-smoke", test={"type": "BUILTIN_FUZZ", "parameters": {
            "event_count": "600", "throttle": "1000", "seed": "42"}},
        executionConfiguration={"jobTimeoutMinutes": 15, "videoCapture": True, "skipAppResign": True})["run"]
    (OUT / "devicefarm.json").write_text(json.dumps({"project": project, "pool": pool,
        "upload": upload["arn"], "run": run["arn"], "apk_sha256": build["sha256"]}, indent=2))
    deadline = time.monotonic() + 1800
    while run["status"] != "COMPLETED" and time.monotonic() < deadline:
        print("Device Farm:", run["status"], flush=True)
        time.sleep(30)
        run = client.get_run(arn=run["arn"])["run"]
    if run["status"] != "COMPLETED":
        client.stop_run(arn=run["arn"])
        raise TimeoutError("Stopped native validation after 30 minutes")
    (OUT / "devicefarm-result.json").write_text(json.dumps(run, default=str, indent=2))
    for kind in ["FILE", "SCREENSHOT", "LOG"]:
        artifacts = [a for page in client.get_paginator("list_artifacts").paginate(arn=run["arn"], type=kind)
                     for a in page["artifacts"]]
        (OUT / ("devicefarm-" + kind.lower() + ".json")).write_text(json.dumps(artifacts, indent=2))
    assert run["result"] == "PASSED", run["result"]
    print("Android fuzz test passed on", devices[0]["name"],
          "— inspect the video for menu and gameplay before declaring the APK playable.")


if __name__ == "__main__":
    main()
