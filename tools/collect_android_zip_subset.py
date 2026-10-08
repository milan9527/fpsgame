"""Read selected Device Farm ZIP members with HTTP ranges, without storing ZIPs."""
import argparse
import fnmatch
import io
import json
from pathlib import Path
import shutil
import time
import urllib.error
import urllib.request
import zipfile


class RangeReader(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.position = 0
        self.size = None
        self._fetch(0, 0)

    def _fetch(self, start, end):
        # Retry the identical bounded read; never advance the cursor or relax
        # response validation when Device Farm's artifact endpoint is busy.
        for attempt in range(4):
            try:
                return self._fetch_once(start, end)
            except urllib.error.HTTPError as error:
                error.close()
                if error.code not in (429, 500, 502, 503, 504) or attempt == 3:
                    raise
                time.sleep(2 ** attempt)

    def _fetch_once(self, start, end):
        request = urllib.request.Request(self.url, headers={
            "Range": f"bytes={start}-{end}", "Accept-Encoding": "identity"})
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise ValueError("Server did not honor bounded range request")
            expected = f"bytes {start}-{end}/"
            content_range = response.headers.get("Content-Range", "")
            if not content_range.startswith(expected):
                raise ValueError("Unexpected content range")
            total = int(content_range[len(expected):])
            if self.size is not None and total != self.size:
                raise ValueError("Archive size changed")
            self.size = total
            data = response.read(end - start + 2)
            if len(data) != end - start + 1:
                raise ValueError("Incomplete or oversized range")
            return data

    def seek(self, offset, whence=0):
        position = offset + (0 if whence == 0 else
                             self.position if whence == 1 else self.size)
        if position < 0:
            raise ValueError("Negative seek")
        self.position = position
        return position

    def tell(self):
        return self.position

    def read(self, size=-1):
        size = self.size - self.position if size < 0 else size
        size = min(size, self.size - self.position)
        if size <= 0:
            return b""
        if size > 16 * 1024 * 1024:
            raise ValueError("Single range exceeds 16 MiB limit")
        data = self._fetch(self.position, self.position + size - 1)
        self.position += len(data)
        return data


def collect(url, destination, patterns, max_bytes):
    destination = Path(destination).resolve()
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RangeReader(url)) as archive:
        selected = [m for m in archive.infolist() if not m.is_dir()
                    and any(fnmatch.fnmatchcase(m.filename, p) for p in patterns)]
        total = sum(m.file_size for m in selected)
        if total > max_bytes or shutil.disk_usage(destination).free < total + 16 * 1024**2:
            raise ValueError("Selected evidence exceeds disk budget")
        targets = []
        for member in selected:
            target = (destination / member.filename).resolve()
            if not target.is_relative_to(destination) or target.exists():
                raise ValueError("Unsafe or existing destination")
            targets.append((member, target))
        for member, target in targets:
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                with archive.open(member) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output, length=65536)
            except Exception:
                target.unlink(missing_ok=True)
                raise
    return [{"name": m.filename, "size": m.file_size} for m in selected]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifact_json", help="Single artifact metadata object containing url")
    parser.add_argument("destination")
    parser.add_argument("patterns", nargs="+", help="ZIP member glob patterns")
    parser.add_argument("--max-bytes", type=int, default=8 * 1024**2)
    args = parser.parse_args()
    metadata = json.loads(Path(args.artifact_json).read_text())
    print(json.dumps(collect(metadata["url"], args.destination, args.patterns,
                             args.max_bytes), indent=2))
