import hashlib
import io
import tarfile

import pytest

from tools.android_shader_source_review import review


def archive(tmp_path, raw, name=None, link=False):
    target = tmp_path / "sources.tar"
    digest = hashlib.sha256(raw).hexdigest()
    with tarfile.open(target, "w") as out:
        entry = tarfile.TarInfo(name or f"files/shader-probe/{digest}.glsl")
        entry.size = len(raw)
        if link:
            entry.type = tarfile.SYMTYPE
            entry.linkname = "/etc/passwd"
        out.addfile(entry, io.BytesIO(raw))
    return target, digest


def marker(digest):
    return (
        "10-08 01:00:00 I godot: IRON_SHADER_PROBE operation=compile_specialization "
        "start_us=100 end_us=9100 duration_us=9000 shader=SceneShaderGLES3 "
        f"variant=0 specialization=16 vertex_sha256={digest} fragment_sha256={digest}"
    )


def test_matches_exact_source_bytes_and_threadtime_log(tmp_path):
    path, digest = archive(tmp_path, b"#define USE_FOG\nvoid main() {}\n")
    result = review(path, marker(digest))
    assert result["all_logged_sources_recovered"]
    assert result["sources"][digest]["defines"] == ["USE_FOG"]
    assert result["calls"][0]["duration_us"] == 9000
    assert not result["acceptance"]


def test_missing_source_and_empty_log_do_not_report_success(tmp_path):
    path, digest = archive(tmp_path, b"source")
    assert not review(path, marker("0" * 64))["all_logged_sources_recovered"]
    assert not review(path, "")["all_logged_sources_recovered"]


@pytest.mark.parametrize("stage", ["vertex", "fragment"])
def test_matches_native_stage_suffixed_source(tmp_path, stage):
    raw = b"#define USE_FOG\nvoid main() {}\n"
    digest = hashlib.sha256(raw).hexdigest()
    path, _ = archive(tmp_path, raw, f"./{digest}.{stage}.glsl")
    result = review(path, marker(digest))
    assert result["all_logged_sources_recovered"]
    assert result["sources"][digest]["member"] == f"./{digest}.{stage}.glsl"


@pytest.mark.parametrize("name,link", [
    ("../" + "0" * 64 + ".glsl", False),
    ("files/" + "0" * 64 + ".glsl", False),
    (None, True),
])
def test_rejects_traversal_hash_mismatch_and_links(tmp_path, name, link):
    path, _ = archive(tmp_path, b"source", name, link)
    with pytest.raises(ValueError):
        review(path, "")
