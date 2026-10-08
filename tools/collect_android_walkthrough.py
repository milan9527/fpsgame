"""Collect completed native Android evidence without interpreting visual quality."""
import json
import os
from pathlib import Path
import zipfile

import boto3
import httpx

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ["ANDROID_BUILD_DIR"]).resolve()


def main():
    metadata = json.loads((OUT / "native-walkthrough-run.json").read_text())
    client = boto3.client("devicefarm", region_name="us-west-2")
    run = client.get_run(arn=metadata["run"])["run"]
    print(run["status"], run["result"], flush=True)
    if run["status"] != "COMPLETED":
        return
    (OUT / "native-walkthrough-result.json").write_text(
        json.dumps(run, default=str, indent=2) + "\n")
    artifacts = []
    for page in client.get_paginator("list_artifacts").paginate(
            arn=metadata["run"], type="FILE"):
        artifacts.extend(page["artifacts"])
    with httpx.Client(timeout=120, follow_redirects=True) as http:
        for index, artifact in enumerate(artifacts):
            if artifact["type"] not in {"TESTSPEC_OUTPUT", "CUSTOMER_ARTIFACT"}:
                continue
            target = OUT / f"native-{index}-{artifact['type']}.{artifact['extension']}"
            response = http.get(artifact["url"])
            response.raise_for_status()
            target.write_bytes(response.content)
            if zipfile.is_zipfile(target):
                destination = OUT / "native-walkthrough-artifacts"
                with zipfile.ZipFile(target) as archive:
                    for member in archive.infolist():
                        resolved = (destination / member.filename).resolve()
                        if not resolved.is_relative_to(destination.resolve()):
                            raise ValueError("Unsafe archive member")
                    archive.extractall(destination)
            print(target, flush=True)


if __name__ == "__main__":
    main()
