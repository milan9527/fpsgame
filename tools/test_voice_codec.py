"""Cross-check Godot's synthetic audio packet with CPython's IMA decoder (3.11)."""
from pathlib import Path
import struct
import subprocess
import warnings

with warnings.catch_warnings():
    warnings.simplefilter("ignore", DeprecationWarning)
    import audioop

ROOT = Path(__file__).resolve().parents[1]


def run():
    result = subprocess.run(
        [str(ROOT / "tools/godot"), "--headless", "--path", "client",
         "--script", "../tests/voice_audio.gd"],
        cwd=ROOT, text=True, capture_output=True, timeout=20, check=True)
    text = result.stdout + result.stderr
    assert "VOICE_AUDIO_PASS" in text and "SCRIPT ERROR" not in text, text
    packet = (ROOT / "artifacts/voice-codec-test.bin").read_bytes()
    # CPython consumes the high nibble first; the game wire format uses low first.
    encoded = bytes((byte >> 4) | ((byte & 15) << 4) for byte in packet[4:])
    frames, _ = audioop.adpcm2lin(encoded, 2, (struct.unpack("<h", packet[:2])[0], packet[2]))
    expected = packet[:2] + frames[:638]
    assert expected == (ROOT / "artifacts/voice-decoded-test.bin").read_bytes()
    print(text.strip())
    print("VOICE_INDEPENDENT_DECODER_PASS samples=320 bit_exact=ok")


if __name__ == "__main__":
    run()
