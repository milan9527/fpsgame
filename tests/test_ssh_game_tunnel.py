"""Framing checks, including fragmented reads and short pipe writes."""
import importlib.util
import io
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "ssh_game_tunnel", Path(__file__).resolve().parents[1] / "tools/ssh_game_tunnel.py")
tunnel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tunnel)


class Fragmented(io.BytesIO):
    def read(self, size=-1):
        return super().read(min(size, 3))


class ShortWrites(io.BytesIO):
    def write(self, data):
        return super().write(data[:7])


class TunnelFramingTests(unittest.TestCase):
    def test_short_writes_and_fragmented_reads_preserve_datagram_boundaries(self):
        output = ShortWrites()
        writer = tunnel.Writer(output)
        packets = [(27015, 1, b"a" * 1400), (27022, 2, b""),
                   (27015, 3, bytes(range(256)) * 200)]
        for packet in packets:
            writer.send(*packet)
        incoming = Fragmented(output.getvalue())
        self.assertEqual([tunnel.receive(incoming) for _ in packets], packets)
        self.assertIsNone(tunnel.receive(incoming))

    def test_destination_and_frame_bounds(self):
        for size, port, peer in [(1, 22, 1), (65508, 27015, 1), (1, 27022, 0)]:
            with self.subTest(size=size, port=port, peer=peer):
                with self.assertRaises(ValueError):
                    tunnel.receive(io.BytesIO(tunnel.HEADER.pack(size, port, peer)))

    def test_truncated_header_and_payload(self):
        for data in [b"x", tunnel.HEADER.pack(2, 27015, 1) + b"x",
                     tunnel.HEADER.pack(1, 27015, 1)]:
            with self.assertRaises(EOFError):
                tunnel.receive(Fragmented(data))


if __name__ == "__main__":
    unittest.main()
