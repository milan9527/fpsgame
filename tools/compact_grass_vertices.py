"""Compact exported grass buffers, preserving indexed corner attributes exactly."""
import copy
import json
import os
from pathlib import Path
import struct
import tempfile


def compact(path):
    path = Path(path)
    raw = path.read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    source = raw[28 + length:]
    # Deliberately limited to our unskinned, non-animated grass exports.
    assert not any(k in doc for k in ("animations", "skins", "images", "extensions"))
    assert len(doc["meshes"]) == len(doc["buffers"]) == 1
    assert len(doc["meshes"][0]["primitives"]) == 1
    primitive = doc["meshes"][0]["primitives"][0]
    assert primitive.get("mode", 4) == 4
    assert "targets" not in primitive and "extensions" not in primitive
    old_accessors = doc["accessors"]
    old_views = doc["bufferViews"]

    def elements(index, width):
        accessor = old_accessors[index]
        assert "sparse" not in accessor
        view = old_views[accessor["bufferView"]]
        assert view["buffer"] == 0
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width)
        result = [source[start + i * stride:start + i * stride + width]
                  for i in range(accessor["count"])]
        assert all(len(value) == width for value in result)
        return result

    index_accessor = old_accessors[primitive["indices"]]
    assert index_accessor["type"] == "SCALAR"
    fmt = {5123: "<H", 5125: "<I"}[index_accessor["componentType"]]
    indices = [struct.unpack(fmt, value)[0] for value in
               elements(primitive["indices"], struct.calcsize(fmt))]
    assert indices and len(indices) % 3 == 0
    # Keep relative vertex order and triangle order unchanged.
    used = sorted(set(indices))
    remap = {old: new for new, old in enumerate(used)}
    binary = bytearray()
    doc["accessors"], doc["bufferViews"] = [], []

    def append(data, accessor, target):
        binary.extend(b"\0" * (-len(binary) % 4))
        view_index = len(doc["bufferViews"])
        doc["bufferViews"].append({
            "buffer": 0, "byteOffset": len(binary),
            "byteLength": len(data), "target": target})
        binary.extend(data)
        accessor = copy.deepcopy(accessor)
        accessor.pop("byteOffset", None)
        accessor["bufferView"] = view_index
        doc["accessors"].append(accessor)
        return len(doc["accessors"]) - 1

    before = old_accessors[primitive["attributes"]["POSITION"]]["count"]
    for semantic, index in list(primitive["attributes"].items()):
        accessor = copy.deepcopy(old_accessors[index])
        assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
        assert accessor["count"] == before and max(used) < before
        values = elements(index, 12)
        selected = [values[i] for i in used]
        assert all(selected[remap[i]] == values[i] for i in indices)
        accessor["count"] = len(used)
        vectors = [struct.unpack("<fff", value) for value in selected]
        for key, operation in (("min", min), ("max", max)):
            if key in accessor:
                accessor[key] = [operation(v[axis] for v in vectors) for axis in range(3)]
        primitive["attributes"][semantic] = append(b"".join(selected), accessor, 34962)
    mapped = [remap[i] for i in indices]
    assert len(used) <= 65536
    primitive["indices"] = append(
        struct.pack("<" + "H" * len(mapped), *mapped),
        {"componentType": 5123, "type": "SCALAR", "count": len(mapped),
         "min": [min(mapped)], "max": [max(mapped)]}, 34963)
    doc["buffers"][0]["byteLength"] = len(binary)
    binary.extend(b"\0" * (-len(binary) % 4))
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    output = (struct.pack("<III", 0x46546C67, 2, 28 + len(encoded) + len(binary))
              + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
              + struct.pack("<II", len(binary), 0x004E4942) + binary)
    if output != raw:
        fd, temporary = tempfile.mkstemp(dir=path.parent, suffix=".glb")
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(output)
            os.chmod(temporary, path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return {"asset": path.name, "vertices_before": before, "vertices_after": len(used),
            "triangles": len(indices) // 3, "bytes_before": len(raw), "bytes_after": len(output)}


if __name__ == "__main__":
    import sys
    for argument in sys.argv[1:]:
        print(json.dumps(compact(argument)))
