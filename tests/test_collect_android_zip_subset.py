import io
from unittest.mock import Mock
import urllib.error

import pytest

from tools.collect_android_zip_subset import RangeReader


def response(data, content_range):
    result = io.BytesIO(data)
    result.status = 206
    result.headers = {"Content-Range": content_range}
    return result


def http_error(code):
    return urllib.error.HTTPError("https://example.invalid/archive", code,
                                  "test failure", {}, None)


def reader(monkeypatch, replies):
    request = Mock(side_effect=replies)
    sleep = Mock()
    monkeypatch.setattr("urllib.request.urlopen", request)
    monkeypatch.setattr("tools.collect_android_zip_subset.time.sleep", sleep)
    return RangeReader("https://example.invalid/archive"), request, sleep


def test_transient_failure_retries_exact_range_without_skipping_bytes(monkeypatch):
    stream, request, sleep = reader(monkeypatch, [
        response(b"a", "bytes 0-0/4"), http_error(503),
        response(b"ab", "bytes 0-1/4"), response(b"cd", "bytes 2-3/4"),
    ])
    assert stream.read(2) + stream.read(2) == b"abcd"
    assert stream.tell() == 4
    assert [call.args[0].get_header("Range") for call in request.call_args_list] == [
        "bytes=0-0", "bytes=0-1", "bytes=0-1", "bytes=2-3",
    ]
    sleep.assert_called_once_with(1)


def test_exhausted_retries_leave_cursor_unchanged(monkeypatch):
    stream, request, sleep = reader(monkeypatch, [
        response(b"a", "bytes 0-0/4"),
        *[http_error(503) for _ in range(4)],
    ])
    with pytest.raises(urllib.error.HTTPError):
        stream.read(2)
    assert stream.tell() == 0
    assert request.call_count == 5
    assert [call.args[0] for call in sleep.call_args_list] == [1, 2, 4]


@pytest.mark.parametrize("failure", [
    http_error(403),
    response(b"ab", "bytes 0-1/5"),
    response(b"a", "bytes 0-1/4"),
])
def test_auth_and_invalid_evidence_are_not_retried(monkeypatch, failure):
    stream, request, sleep = reader(monkeypatch, [
        response(b"a", "bytes 0-0/4"), failure,
    ])
    with pytest.raises((urllib.error.HTTPError, ValueError)):
        stream.read(2)
    assert stream.tell() == 0
    assert request.call_count == 2
    sleep.assert_not_called()
