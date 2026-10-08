"""Apply mobile texture imports only to the isolated Android source snapshot."""
import hashlib
import re
from pathlib import Path


def apply_texture_policy(client: Path) -> dict:
    changed = {}
    for path in sorted((client / "assets").rglob("*.import")):
        text = path.read_text()
        # UI, fonts and non-texture importers must not acquire 3D compression.
        if 'importer="texture"' not in text or "mipmaps/generate=true" not in text:
            continue
        text, count = re.subn(r"(?m)^compress/mode=\d+$", "compress/mode=2", text)
        assert count == 1, path
        text, count = re.subn(r"(?m)^process/size_limit=\d+$", "process/size_limit=1024", text)
        assert count == 1, path
        path.write_text(text)
        changed[str(path.relative_to(client))] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert changed, "No 3D texture imports found"
    return {"max_dimension": 1024, "compression": "VRAM", "imports": changed}
