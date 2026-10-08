"""Expose health only after the actual Godot server reports readiness."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import signal
import subprocess
import sys
import threading
import time

ready = threading.Event()


class Health(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200 if self.path == "/health" and ready.is_set() else 503)
        self.end_headers()

    def log_message(self, *_args):
        pass


if __name__ == "__main__":
    # Single-task rooms stop before replacement; let the old Redis lease expire.
    time.sleep(15)
    process = subprocess.Popen(
        ["/app/IronMeridian", "--headless", "--main-pack", "/app/IronMeridian.pck",
         "--script", "/app/network_bootstrap.gd", "--", "--server"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    signal.signal(signal.SIGTERM, lambda *_: process.terminate())
    signal.signal(signal.SIGINT, lambda *_: process.terminate())
    server = ThreadingHTTPServer(("0.0.0.0", 8765), Health)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    for line in process.stdout:
        print(line, end="", flush=True)
        if "SERVER_READY " in line:
            ready.set()
    ready.clear()
    server.shutdown()
    sys.exit(process.wait())
