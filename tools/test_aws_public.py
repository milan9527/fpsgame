"""Verify public download/API surfaces, private S3, and native clients against AWS."""
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import time

import httpx

ROOT = Path(__file__).resolve().parents[1]


class Forms(HTMLParser):
    def __init__(self):
        super().__init__()
        self.forms = []

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if tag == "form" or (tag == "input" and attributes.get("type", "").lower() == "password"):
            self.forms.append(tag)


def main():
    outputs = json.loads((ROOT / "infra/aws/deployment-outputs.json").read_text())["IronMeridian"]
    base, api = outputs["Website"], outputs["ApiUrl"]
    evidence = ROOT / "artifacts/aws-public-verification"
    evidence.mkdir(exist_ok=True)
    report = {"status": "running", "website": base, "api": api, "routes": {}, "accounts": []}
    with httpx.Client(timeout=30, follow_redirects=True) as client:
        website = client.get(base + "/")
        assert website.status_code == 200
        parser = Forms()
        parser.feed(website.text)
        assert not parser.forms and "下载 Linux" in website.text
        report["website_has_login_form"] = False
        for suffix in ["/login", "/register", "/signin", "/signup", "/docs", "/redoc", "/openapi.json",
                       "/api", "/api/login", "/api/register", "/api/docs", "/api/redoc",
                       "/api/openapi.json", "/api/docs/oauth2-redirect", "/api/internal/rooms/heartbeat"]:
            response = client.get(base + suffix)
            assert response.status_code in (403, 404), (suffix, response.status_code)
            parser = Forms()
            parser.feed(response.text)
            assert not parser.forms, suffix
            report["routes"][suffix] = response.status_code
        for suffix in ["/auth/login", "/auth/register"]:
            response = client.get(api + suffix)
            assert response.status_code == 405 and "application/json" in response.headers["content-type"]
            report["routes"]["/api" + suffix] = response.status_code
        assert client.get(api + "/health").status_code == 200
        manifest = json.loads((ROOT / "client/protocol.json").read_text())
        assert client.get(api + "/protocol").json() == manifest
        s3 = client.get("https://" + outputs["DownloadsBucket"] + ".s3.us-east-1.amazonaws.com/index.html")
        assert s3.status_code == 403
        report["direct_s3_http"] = 403
        private_accounts = json.loads((ROOT / "artifacts/test-accounts.json").read_text())
        credentials = [private_accounts["network-" + str(i)] for i in range(2)]
        for account in credentials:
            response = client.post(api + "/auth/login", json=account)
            assert response.status_code == 200, "Migrated test account could not sign in"
            profile = client.get(api + "/profile", headers={"Authorization": "Bearer " + response.json()["token"]})
            assert profile.status_code == 200 and profile.json()["username"] == account["username"]
            wrong = client.post(api + "/auth/login", json=dict(account, password=account["password"] + "-invalid"))
            assert wrong.status_code == 401
            report["accounts"].append({"username": account["username"], "login_http": 200,
                                       "profile_http": 200, "wrong_password_http": 401})
        with tempfile.TemporaryDirectory(prefix="aws-native-verify-", dir=ROOT / "artifacts") as temp:
            temp = Path(temp)
            archive = temp / "game.tar.gz"
            with client.stream("GET", outputs["DownloadUrl"], timeout=120) as response:
                response.raise_for_status()
                with archive.open("wb") as file:
                    for chunk in response.iter_bytes():
                        file.write(chunk)
            report["download_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
            assert report["download_sha256"] == "e2a94bca580253e22f4df38d9fc3ec145d4d8fc139e874ece5aa9297212bcb69"
            with tarfile.open(archive) as bundle:
                bundle.extractall(temp, filter="data")
            processes = []
            try:
                for mode, port in [("solo", 27015), ("duo", 27022)]:
                    pending = []
                    for index, account in enumerate(credentials):
                        path = evidence / f"{mode}-client-{index}.log"
                        stream = path.open("w")
                        env = dict(os.environ, TEST_USERNAME=account["username"], TEST_PASSWORD=account["password"],
                                   API_URL=api, TEST_ROOM_ID=f"room-{port}", TEST_GAME_MODE=mode,
                                   XDG_DATA_HOME=str(temp / f"{mode}-profile-{index}"))
                        process = subprocess.Popen([
                            str(temp / "IronMeridian-Linux/play.sh"), "--headless", "--max-fps", "60",
                            "--script", str(ROOT / "tests/ssh_tunnel_client.gd"), "--", "--bot-client"],
                            env=env, stdout=stream, stderr=subprocess.STDOUT)
                        processes.append((process, stream))
                        pending.append((process, stream, path))
                    for process, stream, path in pending:
                        code = process.wait(timeout=65)
                        stream.flush()
                        text = path.read_text()
                        assert code == 0 and "ONLINE_CLIENT_PASS" in text and "SCRIPT ERROR" not in text, text[-1800:]
                    report[mode + "_native_clients"] = 2
                    time.sleep(3)
            finally:
                for process, stream in processes:
                    if process.poll() is None:
                        process.kill()
                        process.wait()
                    stream.close()
    report.update(status="passed", scope="Real CloudFront HTTPS and public NLB UDP, native clients downloaded from the website; tests originate from the existing EC2 host.")
    (evidence / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("AWS_PUBLIC_VERIFY_PASS no_login_pages=ok private_s3=ok migrated_login=ok download=ok solo_duo_native_clients=ok")


if __name__ == "__main__":
    main()
