"""Publish a verified Android APK through the existing private S3/OAC site."""
import hashlib
import json
from pathlib import Path
import time
import uuid

import boto3
import httpx

from test_aws_public import Forms

ROOT = Path(__file__).resolve().parents[1]


def verify_build(build):
    network = json.loads((ROOT / "artifacts/android-build/source-network.json").read_text())
    native = json.loads((ROOT / "artifacts/android-build/devicefarm-result.json").read_text())
    memory = json.loads((ROOT / "artifacts/android-build/login-memory-auth.json").read_text())
    assert memory["status"] == "passed" and memory["apk_sha256"] == build["sha256"]
    assert network["apk_sha256"] == build["sha256"]
    for evidence, marker in [("login-memory-test.log", "REMEMBERED_LOGIN_PASS"),
                             ("login-memory-ui.log", "LOGIN_MEMORY_UI_PASS"),
                             ("aim-alignment.log", "AIM_ALIGNMENT_PASS")]:
        assert marker in (ROOT / "artifacts/android-build" / evidence).read_text()
    assert network["status"] == "passed" and set(network["checks"]) == {"solo", "duo"}
    native_build = json.loads((ROOT / "artifacts/android-build/devicefarm.json").read_text())
    assert native_build["apk_sha256"] == build["sha256"] and native_build["run"] == native["arn"]
    assert native["result"] == "PASSED", "Native Device Farm test must pass"
    assert "MOBILE_CONTROLS_PASS" in (ROOT / "artifacts/android-build/final-touch-test.log").read_text()
    assert hashlib.sha256((ROOT / "client/scripts/mobile_controls.gd").read_bytes()).hexdigest() == build["touch_source_sha256"]
    import subprocess
    subprocess.run([str(ROOT / "artifacts/android-sdk/build-tools/35.0.0/apksigner"),
                    "verify", build["apk"]], check=True)


def main():
    build = json.loads((ROOT / "artifacts/android-build/build.json").read_text())
    verify_build(build)
    archive = Path(build["apk"])
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == build["sha256"]
    site = ROOT / "infra/aws/site"
    assert build["sha256"] in (site / "index.html").read_text()
    state = json.loads((ROOT / "artifacts/aws-direct/state.json").read_text())
    session = boto3.Session(region_name="us-east-1")
    s3, cloudfront = session.client("s3"), session.client("cloudfront")
    key = "downloads/" + archive.name
    s3.upload_file(str(archive), state["download_bucket"], key, ExtraArgs={
        "ContentType": "application/vnd.android.package-archive", "CacheControl": "no-cache",
        "ContentDisposition": 'attachment; filename="' + archive.name + '"',
    })
    for name, kind in [("index.html", "text/html; charset=utf-8"), ("style.css", "text/css"),
                       ("android-download-qr.png", "image/png")]:
        s3.put_object(Bucket=state["download_bucket"], Key=name, Body=(site / name).read_bytes(),
                      ContentType=kind, CacheControl="no-cache")
    invalidation = cloudfront.create_invalidation(
        DistributionId=state["distribution"]["Id"], InvalidationBatch={
            "CallerReference": "android-" + uuid.uuid4().hex,
            "Paths": {"Quantity": 5, "Items": ["/", "/index.html", "/style.css", "/android-download-qr.png", "/" + key]},
        })["Invalidation"]["Id"]
    deadline = time.monotonic() + 900
    while time.monotonic() < deadline:
        if cloudfront.get_invalidation(DistributionId=state["distribution"]["Id"],
                                      Id=invalidation)["Invalidation"]["Status"] == "Completed":
            break
        time.sleep(15)
    else:
        raise TimeoutError("CloudFront invalidation still pending")
    base = "https://" + state["distribution"]["DomainName"]
    with httpx.Client(timeout=60) as client:
        page = client.get(base + "/")
        assert page.status_code == 200 and archive.name in page.text and build["sha256"] in page.text
        forms = Forms()
        forms.feed(page.text)
        assert not forms.forms
        with client.stream("GET", base + "/" + key) as response:
            response.raise_for_status()
            digest = hashlib.sha256()
            for chunk in response.iter_bytes():
                digest.update(chunk)
        assert digest.hexdigest() == build["sha256"]
        assert client.get(base + "/login").status_code in [403, 404]
        assert client.get(base + "/api/docs").status_code == 404
        assert client.get(base + "/api/auth/login").status_code == 405
    report = {"status": "passed", "website": base, "download": base + "/" + key,
              "sha256": build["sha256"], "public_download_matches_tested_archive": True,
              "website_has_login_form": False}
    (ROOT / "artifacts/android-build/publication.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
