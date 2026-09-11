"""Bounded loopback UDP relay for real ENet integration tests."""
import heapq
import random
import selectors
import socket
import threading
import time


class ImpairedUDP:
    def __init__(self, destination_port, seed):
        self.destination = ("127.0.0.1", int(destination_port))
        self.rng = random.Random(seed)
        self.selector = selectors.DefaultSelector()
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        for sock in (self.front, self.upstream):
            sock.bind(("127.0.0.1", 0))
            sock.setblocking(False)
            self.selector.register(sock, selectors.EVENT_READ)
        self.port = self.front.getsockname()[1]
        self.stop = threading.Event()
        self.blackout_until = 0.0
        self.errors = []
        self.stats = {side: dict(received=0, forwarded=0, random_drops=0,
                                outage_drops=0, reordered_schedule=0) for side in ("up", "down")}
        self.stats["peak_queue"] = 0
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def _run(self):
        client = None
        pending = []
        serial = 0
        previous_due = {"up": 0.0, "down": 0.0}
        try:
            while not self.stop.is_set():
                for key, _ in self.selector.select(0.002):
                    data, address = key.fileobj.recvfrom(65535)
                    if key.fileobj is self.front:
                        if client is not None and address != client:
                            continue
                        client = address
                        side, sender, destination = "up", self.upstream, self.destination
                    else:
                        if address != self.destination or client is None:
                            continue
                        side, sender, destination = "down", self.front, client
                    self.stats[side]["received"] += 1
                    now = time.monotonic()
                    if side == "up" and now < self.blackout_until:
                        self.stats[side]["outage_drops"] += 1
                        continue
                    if self.rng.random() < 0.03:
                        self.stats[side]["random_drops"] += 1
                        continue
                    due = now + self.rng.uniform(0.050, 0.100)
                    if due < previous_due[side]:
                        self.stats[side]["reordered_schedule"] += 1
                    previous_due[side] = due
                    serial += 1
                    assert len(pending) < 2048, "UDP test relay queue overflow"
                    heapq.heappush(pending, (due, serial, side, sender, destination, data))
                    self.stats["peak_queue"] = max(self.stats["peak_queue"], len(pending))
                while pending and pending[0][0] <= time.monotonic():
                    _, _, side, sender, destination, data = heapq.heappop(pending)
                    if side == "up" and time.monotonic() < self.blackout_until:
                        self.stats[side]["outage_drops"] += 1
                        continue
                    sender.sendto(data, destination)
                    self.stats[side]["forwarded"] += 1
        except Exception as error:
            self.errors.append(repr(error))

    def close(self):
        self.stop.set()
        self.thread.join(timeout=2)
        assert not self.thread.is_alive(), "UDP relay failed to stop"
        self.selector.close()
        self.front.close()
        self.upstream.close()
