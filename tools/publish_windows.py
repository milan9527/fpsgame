"""Publish a verified Windows package through the existing private S3/OAC site."""
import hashlib
import json
from pathlib import Path
import time
import uuid

import boto3
import httpx

from test_aws_public import Forms

ROOT = Path(__file__).resolve().parents[1]


def main():
    build = json.loads((ROOT / "artifacts/windows-build/build.json").read_text())
    tests = json.loads((ROOT / "artifacts/windows-verification/verification.json").read_text())
    assert tests["status"] == "passed" and tests["archive_sha256"] == build["sha256"]
    assert {"menu", "solo", "duo", "aim", "online-solo-0", "online-solo-1",
            "online-duo-0", "online-duo-1"}.issubset(tests["checks"])
    archive = Path(build["archive"])
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == build["sha256"]
    site = ROOT / "infra/aws/site"
    assert build["sha256"] in (site / "index.html").read_text()
    state = json.loads((ROOT / "artifacts/aws-direct/state.json").read_text())
    session = boto3.Session(region_name="us-east-1")
    s3, cloudfront = session.client("s3"), session.client("cloudfront")
    key = "downloads/" + archive.name
    s3.upload_file(str(archive), state["download_bucket"], key, ExtraArgs={
        "ContentType": "application/zip", "CacheControl": "no-cache",
        "ContentDisposition": 'attachment; filename="' + archive.name + '"',
    })
    for name, kind in [("index.html", "text/html; charset=utf-8"), ("style.css", "text/css"),
                       ("android-download-qr.png", "image/png")]:
        s3.put_object(Bucket=state["download_bucket"], Key=name, Body=(site / name).read_bytes(),
                      ContentType=kind, CacheControl="no-cache")
    invalidation = cloudfront.create_invalidation(
        DistributionId=state["distribution"]["Id"], InvalidationBatch={
            "CallerReference": "windows-" + uuid.uuid4().hex,
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
    (ROOT / "artifacts/windows-verification/publication.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
