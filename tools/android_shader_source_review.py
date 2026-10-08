"""Match diagnostic shader source archives to logged compilation identities."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tarfile


IDENTITY = re.compile(
    r"IRON_SHADER_PROBE operation=compile_specialization "
    r"start_us=(\d+) end_us=(\d+) duration_us=(\d+) "
    r"shader=(\w+) variant=(\d+) specialization=(\d+) "
    r"vertex_sha256=([0-9a-f]{64}) fragment_sha256=([0-9a-f]{64})"
)


def review(archive_path, log_text):
    sources = {}
    total_bytes = 0
    with tarfile.open(archive_path) as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError("Unsafe shader archive path")
            if member.isdir():
                continue
            identity = re.fullmatch(r"([0-9a-f]{64})(?:\.(vertex|fragment))?\.glsl", path.name)
            if not member.isfile() or not identity:
                raise ValueError("Unexpected shader archive member")
            total_bytes += member.size
            if member.size > 4 * 1024**2 or total_bytes > 64 * 1024**2:
                raise ValueError("Shader source archive exceeds review budget")
            raw = archive.extractfile(member).read()
            digest = hashlib.sha256(raw).hexdigest()
            if digest != identity.group(1):
                raise ValueError("Shader source hash mismatch")
            if digest in sources:
                raise ValueError("Duplicate shader source")
            text = raw.decode("utf-8")
            sources[digest] = {
                "member": member.name,
                "bytes": len(raw),
                "defines": re.findall(r"^\s*#define\s+(.+)$", text, re.MULTILINE),
            }
    calls = []
    for line_number, line in enumerate(log_text.splitlines(), 1):
        if "IRON_SHADER_PROBE operation=compile_specialization " not in line:
            continue
        match = IDENTITY.search(line)
        if not match:
            raise ValueError(f"Missing shader identity at line {line_number}")
        start, end, duration, shader, variant, specialization, vertex, fragment = match.groups()
        if int(end) - int(start) != int(duration) or int(duration) < 8000:
            raise ValueError("Invalid diagnostic scope timing")
        calls.append({
            "log_line": line_number,
            "shader": shader,
            "variant": int(variant),
            "specialization": int(specialization),
            "duration_us": int(duration),
            "vertex_sha256": vertex,
            "fragment_sha256": fragment,
            "missing_sources": [digest for digest in (vertex, fragment) if digest not in sources],
        })
    return {
        "diagnostic_only": True,
        "acceptance": False,
        "limitations": [
            "Sources and timing come from an instrumented engine with logging and file I/O.",
            "Source identity alone does not identify a project material or prove a presentation stall.",
            "Only logged slow compilations are matched; this is not a complete shader inventory.",
        ],
        "archive_sha256": hashlib.sha256(Path(archive_path).read_bytes()).hexdigest(),
        "log_text_sha256": hashlib.sha256(log_text.encode()).hexdigest(),
        "all_logged_sources_recovered": bool(calls) and all(not c["missing_sources"] for c in calls),
        "calls": calls,
        "sources": sources,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("logcat", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = review(args.archive, args.logcat.read_text())
    with args.output.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")


if __name__ == "__main__":
    main()
