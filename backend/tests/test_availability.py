"""Real failed sockets and pool exhaustion in a separate API test process."""
import logging
import socket
import time
import threading
import redis
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session
import app.main as main


def assert_unavailable(response):
    assert response.status_code == 503
    assert response.headers['retry-after'] == '3'
    assert response.headers['cache-control'] == 'no-store'
    assert response.json() == {'detail': 'Online services are temporarily unavailable. Please try again shortly.'}


def unused_port():
    sock = socket.socket()
    sock.bind(('127.0.0.1', 0))
    return sock


def test_real_redis_connection_refused(monkeypatch, caplog):
    # Bound but not listening: the port cannot be reused by an unrelated service.
    with unused_port() as sock:
        unavailable = redis.Redis(host='127.0.0.1', port=sock.getsockname()[1], socket_timeout=2, socket_connect_timeout=2)
        monkeypatch.setattr(main, 'cache', unavailable)
        with TestClient(main.app) as client, caplog.at_level(logging.WARNING):
            started = time.monotonic()
            assert_unavailable(client.get('/health'))
            assert time.monotonic() - started < 4
            response = client.post('/auth/login', json={'username': 'outage_probe', 'password': 'outage-private-password'})
            assert_unavailable(response)
            assert 'outage-private-password' not in response.text
        unavailable.close()
    assert 'dependency_unavailable category=ConnectionError' in caplog.text
    assert '127.0.0.1' not in caplog.text


def test_real_database_connection_refused():
    with unused_port() as sock:
        url = make_url(main.engine.url).set(host='127.0.0.1', port=sock.getsockname()[1], password='never-echo-this-password')
        unavailable = create_engine(url, connect_args={'connect_timeout': 2})
        def isolated_session():
            with Session(unavailable) as session:
                yield session
        main.app.dependency_overrides[main.db] = isolated_session
        try:
            with TestClient(main.app) as client:
                response = client.get('/health')
                assert_unavailable(response)
                assert 'never-echo-this-password' not in response.text
        finally:
            main.app.dependency_overrides.clear()
            unavailable.dispose()


def test_real_pool_exhaustion_then_recovery():
    isolated = create_engine(main.engine.url, pool_size=1, max_overflow=0, pool_timeout=.1)
    def isolated_session():
        with Session(isolated) as session:
            yield session
    main.app.dependency_overrides[main.db] = isolated_session
    try:
        with TestClient(main.app) as client:
            with isolated.connect():
                assert_unavailable(client.get('/health'))
            assert client.get('/health').status_code == 200
    finally:
        main.app.dependency_overrides.clear()
        isolated.dispose()


def test_real_redis_read_timeout(monkeypatch):
    stop = threading.Event()
    with unused_port() as listener:
        listener.listen(1)
        listener.settimeout(5)
        def silent_server():
            with listener.accept()[0]:
                stop.wait(5)
        worker = threading.Thread(target=silent_server, daemon=True)
        worker.start()
        unavailable = redis.Redis(host='127.0.0.1', port=listener.getsockname()[1],
                                  socket_connect_timeout=2, socket_timeout=2, retry_on_timeout=False)
        monkeypatch.setattr(main, 'cache', unavailable)
        try:
            with TestClient(main.app) as client:
                started = time.monotonic()
                assert_unavailable(client.get('/health'))
                assert 1.5 < time.monotonic() - started < 4
        finally:
            stop.set()
            unavailable.close()
            worker.join(timeout=3)
        assert not worker.is_alive()
