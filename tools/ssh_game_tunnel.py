#!/usr/bin/env python3
"""Forward the game's TCP API and UDP datagrams over one authenticated SSH connection.

Run this file on the player's computer (Python 3.9+ and OpenSSH required).
Only the server's loopback API and two fixed game ports are reachable.
"""
import argparse
import base64
from pathlib import Path
import shlex
import socket
import struct
import subprocess
import sys
import threading
import time

PORTS = (27015, 27022)
HEADER = struct.Struct("!IHI")  # datagram length, destination port, local peer id
MAX_DATAGRAM = 65507
MAX_PEERS = 64
IDLE_SECONDS = 90


def receive(stream):
    def exact(size):
        data = bytearray()
        while len(data) < size:
            part = stream.read(size - len(data))
            if not part:
                if not data:
                    return None
                raise EOFError("Truncated SSH tunnel frame")
            data.extend(part)
        return bytes(data)
    header = exact(HEADER.size)
    if header is None:
        return None
    size, port, peer = HEADER.unpack(header)
    if size > MAX_DATAGRAM or port not in PORTS or peer == 0:
        raise ValueError("Invalid SSH tunnel frame")
    payload = exact(size) if size else b""
    if payload is None:
        raise EOFError("Truncated SSH tunnel datagram")
    return port, peer, payload


class Writer:
    def __init__(self, stream):
        self.stream = stream
        self.lock = threading.Lock()

    def send(self, port, peer, payload):
        with self.lock:
            data = memoryview(HEADER.pack(len(payload), port, peer) + payload)
            while data:
                written = self.stream.write(data)
                if not written:
                    raise BrokenPipeError("SSH stream closed")
                data = data[written:]
            self.stream.flush()


def relay():
    """SSH remote command. Stdout is exclusively a framed binary stream."""
    writer = Writer(sys.stdout.buffer)
    peers = {}
    lock = threading.Lock()
    stopping = threading.Event()

    def responses(key, sock, entry):
        try:
            while not stopping.is_set():
                try:
                    payload = sock.recv(MAX_DATAGRAM)
                    writer.send(key[0], key[1], payload)
                except socket.timeout:
                    if time.monotonic() - entry[1] >= IDLE_SECONDS:
                        break
                except ConnectionRefusedError:
                    time.sleep(0.05)
        except (OSError, ValueError):
            stopping.set()
        finally:
            with lock:
                if peers.get(key) is entry:
                    del peers[key]
            sock.close()

    try:
        while not stopping.is_set():
            frame = receive(sys.stdin.buffer)
            if frame is None:
                break
            port, peer, payload = frame
            key = (port, peer)
            with lock:
                entry = peers.get(key)
                if entry is None:
                    if len(peers) >= MAX_PEERS:
                        continue
                    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    sock.connect(("127.0.0.1", port))
                    sock.settimeout(1)
                    entry = [sock, time.monotonic()]
                    peers[key] = entry
                    threading.Thread(target=responses, args=(key, sock, entry), daemon=True).start()
                entry[1] = time.monotonic()
                entry[0].send(payload)
    finally:
        stopping.set()
        with lock:
            for entry in peers.values():
                entry[0].close()


def client(args):
    # Upload the helper through the SSH command, not a persistent remote file.
    code = base64.b64encode(Path(__file__).read_bytes()).decode("ascii")
    remote = "python3 -u -c " + shlex.quote(
        "import base64;exec(compile(base64.b64decode(" + repr(code) + "),'<ssh-game-relay>','exec'))"
    ) + " --relay"
    command = ["ssh", "-T", "-o", "ExitOnForwardFailure=yes", "-o", "ServerAliveInterval=15",
               "-o", "ServerAliveCountMax=3", "-p", str(args.ssh_port),
               "-L", f"127.0.0.1:{args.api_port}:127.0.0.1:{args.remote_api_port}"]
    if args.identity:
        command += ["-i", args.identity]
    if args.known_hosts:
        command += ["-o", "UserKnownHostsFile=" + args.known_hosts, "-o", "StrictHostKeyChecking=yes"]
    command += [args.target, remote]
    sockets = {}
    process = None
    peers = {}
    lock = threading.Lock()
    stopping = threading.Event()
    next_id = 1
    try:
        for remote_port, local_port in zip(PORTS, (args.solo_port, args.duo_port)):
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sockets[remote_port] = sock
            sock.bind(("127.0.0.1", local_port))
            sock.settimeout(1)
        process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
        writer = Writer(process.stdin)

        def datagrams(port, sock):
            nonlocal next_id
            try:
                while not stopping.is_set():
                    try:
                        payload, address = sock.recvfrom(MAX_DATAGRAM)
                    except socket.timeout:
                        continue
                    with lock:
                        now = time.monotonic()
                        for key, entry in list(peers.items()):
                            if now - entry[1] >= IDLE_SECONDS:
                                del peers[key]
                        key = (port, address)
                        if key not in peers:
                            if len(peers) >= MAX_PEERS:
                                continue
                            peers[key] = [next_id, now]
                            next_id += 1
                        peer = peers[key][0]
                        peers[key][1] = now
                    writer.send(port, peer, payload)
            except (OSError, ValueError):
                stopping.set()
                if process.poll() is None:
                    process.terminate()

        for port, sock in sockets.items():
            threading.Thread(target=datagrams, args=(port, sock), daemon=True).start()
        print(f"Connecting SSH tunnel. Game API: http://127.0.0.1:{args.api_port}", flush=True)
        print("Keep this terminal open while playing. Press Ctrl+C to disconnect.", flush=True)
        while True:
            frame = receive(process.stdout)
            if frame is None:
                break
            port, peer, payload = frame
            with lock:
                address = next((key[1] for key, entry in peers.items()
                                if key[0] == port and entry[0] == peer), None)
            if address is not None:
                sockets[port].sendto(payload, address)
        code = process.wait(timeout=5)
        if code:
            raise RuntimeError(f"SSH exited with status {code}; check the SSH message above")
    finally:
        stopping.set()
        for sock in sockets.values():
            sock.close()
        if process is not None:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            process.stdin.close()
            process.stdout.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", nargs="?", help="SSH destination, e.g. ec2-user@54.172.49.143")
    parser.add_argument("-i", "--identity", help="SSH private key path (stays on your computer)")
    parser.add_argument("--ssh-port", type=int, default=22)
    parser.add_argument("--api-port", type=int, default=8000)
    parser.add_argument("--remote-api-port", type=int, default=8000,
                        help="API port on the SSH server (current development server: 8002)")
    parser.add_argument("--solo-port", type=int, default=27015, help="Local UDP port; normal game requires 27015")
    parser.add_argument("--duo-port", type=int, default=27022, help="Local UDP port; normal game requires 27022")
    parser.add_argument("--known-hosts", help="Optional existing SSH known_hosts file")
    parser.add_argument("--relay", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.relay:
        relay()
    elif args.target and not args.target.startswith("-"):
        client(args)
    else:
        parser.error("Specify your SSH destination")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (OSError, EOFError, ValueError, RuntimeError) as error:
        print(f"Tunnel failed: {error}", file=sys.stderr)
        sys.exit(1)
