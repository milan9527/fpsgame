"""Remove coincident-position triangles without changing grass vertex streams.

Grass wind uses position and per-instance constants, so coincident positions
remain coincident after deformation. Do not extend this to arbitrary shaders.
"""
import json
from pathlib import Path
import struct
import os
import tempfile


def strip(path):
    path = Path(path)
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = bytearray(raw[28 + length:])

    def read(index):
        a = doc["accessors"][index]
        v = doc["bufferViews"][a["bufferView"]]
        assert "sparse" not in a
        fmt = "<" + {5123: "H", 5125: "I", 5126: "f"}[a["componentType"]] * {
            "SCALAR": 1, "VEC3": 3}[a["type"]]
        start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = v.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, binary, start + i * stride)
                for i in range(a["count"])]

    before = after = 0
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4 and "targets" not in primitive
            positions = read(primitive["attributes"]["POSITION"])
            indices = [i[0] for i in read(primitive["indices"])]
            assert len(indices) % 3 == 0
            kept = []
            for offset in range(0, len(indices), 3):
                triangle = indices[offset:offset + 3]
                if len({positions[i] for i in triangle}) == 3:
                    kept.extend(triangle)
            before += len(indices) // 3
            after += len(kept) // 3
            if len(kept) == len(indices):
                continue
            assert kept
            binary.extend(b"\0" * (-len(binary) % 4))
            view = len(doc["bufferViews"])
            doc["bufferViews"].append({
                "buffer": 0, "byteOffset": len(binary),
                "byteLength": len(kept) * 4, "target": 34963})
            binary.extend(struct.pack("<" + "I" * len(kept), *kept))
            primitive["indices"] = len(doc["accessors"])
            doc["accessors"].append({
                "bufferView": view, "componentType": 5125,
                "count": len(kept), "type": "SCALAR",
                "min": [min(kept)], "max": [max(kept)]})
    if before != after:
        doc["buffers"][0]["byteLength"] = len(binary)
        encoded = json.dumps(doc, separators=(",", ":")).encode()
        encoded += b" " * (-len(encoded) % 4)
        output = (struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(binary))
                  + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
                  + struct.pack("<II", len(binary), 0x004E4942) + binary)
        # Build snapshots can hardlink assets: replace only this directory entry.
        fd, temporary = tempfile.mkstemp(dir=path.parent, suffix=".glb")
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(output)
            os.chmod(temporary, path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return {"asset": path.name, "before": before, "after": after}


if __name__ == "__main__":
    import sys
    for argument in sys.argv[1:]:
        print(json.dumps(strip(argument)))
