"""Merge mobile fir needle surfaces using an embedded, nearest-filtered palette.

Restricted to the identity-transform, static Blender export used by this project.
Reject unexpected inputs rather than silently changing geometry or materials.
Palette pixels are sRGB; glTF material factors are linear. A texture avoids the
Godot 4.4 Compatibility renderer's differing treatment of vertex/material color.
"""
import copy
import json
from pathlib import Path
import struct
import sys
import zlib


def merge(source: Path, destination: Path, shrub: bool = False) -> None:
    raw = source.read_bytes()
    assert raw[:4] == b"glTF"
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    offset = 20 + length
    binary_length, kind = struct.unpack_from("<II", raw, offset)
    assert kind == 0x004E4942
    binary = bytearray(raw[offset + 8:offset + 8 + binary_length])
    assert len(doc["buffers"]) == 1
    assert not any(k in doc for k in ("skins", "animations"))
    nodes = doc["nodes"]
    if shrub:
        # Shrubs use one identity node with five opaque palette primitives.
        assert len(nodes) == 1 and set(nodes[0]) <= {"mesh", "name"}
        primitives = doc["meshes"][nodes[0]["mesh"]]["primitives"]
        assert len(primitives) == 5
        assert {doc["materials"][p["material"]]["name"] for p in primitives} == {
            "twigs", "shade", "olive", "sage", "new_growth"}
        doc["meshes"] = [{"primitives": [p]} for p in primitives]
        nodes = [{"mesh": i} for i in range(len(primitives))]
        doc["nodes"] = nodes
        doc["scenes"][0]["nodes"] = list(range(len(nodes)))
    assert all(set(n) <= {"mesh", "name"} for n in nodes)
    assert doc["scenes"][0]["nodes"] == list(range(len(nodes)))
    assert len(doc["scenes"]) == 1
    needles, retained = [], []
    reference = None
    for node in nodes:
        mesh = doc["meshes"][node["mesh"]]
        assert len(mesh["primitives"]) == 1
        primitive = mesh["primitives"][0]
        material = doc["materials"][primitive["material"]]
        if not shrub and not material["name"].startswith("Needles"):
            retained.append(node)
            continue
        assert set(primitive) <= {"attributes", "indices", "material", "mode"}
        assert primitive.get("mode", 4) == 4
        assert set(primitive["attributes"]) == (
            {"POSITION", "NORMAL"} if shrub else {"POSITION", "NORMAL", "TEXCOORD_0"})
        normalized = copy.deepcopy(material)
        normalized.pop("name")
        color = normalized["pbrMetallicRoughness"].pop("baseColorFactor")
        assert color[3] == 1 and normalized.get("alphaMode", "OPAQUE") == "OPAQUE"
        if reference is None:
            reference = normalized
        assert normalized == reference
        needles.append((primitive, color))
    assert (len(needles), len(retained)) == ((5, 0) if shrub else (4, 1))

    def read(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        assert "sparse" not in accessor and not accessor.get("normalized", False)
        assert view["buffer"] == 0
        widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
        fmt = "<" + {5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]] * widths[accessor["type"]]
        size = struct.calcsize(fmt)
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", size)
        return [struct.unpack_from(fmt, binary, start + i * stride)
                for i in range(accessor["count"])]

    streams = {key: [] for key in ("POSITION", "NORMAL", "TEXCOORD_0")}
    indices = []
    for palette_index, (primitive, color) in enumerate(needles):
        base = len(streams["POSITION"])
        positions = read(primitive["attributes"]["POSITION"])
        for key in ("POSITION", "NORMAL"):
            values = read(primitive["attributes"][key])
            assert len(values) == len(positions)
            streams[key].extend(values)
        streams["TEXCOORD_0"].extend(
            [((palette_index + 0.5) / len(needles), 0.5)] * len(positions))
        original_indices = read(primitive["indices"])
        assert all(0 <= i[0] < len(positions) for i in original_indices)
        indices.extend([(i[0] + base,) for i in original_indices])

    def append(values, component, shape, target):
        binary.extend(b"\0" * (-len(binary) % 4))
        start = len(binary)
        fmt = "<" + ("f" if component == 5126 else "I") * len(values[0])
        for value in values:
            binary.extend(struct.pack(fmt, *value))
        view_id = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": start,
                                  "byteLength": len(binary) - start, "target": target})
        accessor = {"bufferView": view_id, "componentType": component,
                    "count": len(values), "type": shape}
        if shape == "VEC3":
            accessor["min"] = [min(v[i] for v in values) for i in range(3)]
            accessor["max"] = [max(v[i] for v in values) for i in range(3)]
        doc["accessors"].append(accessor)
        return len(doc["accessors"]) - 1

    attributes = {key: append(values, 5126, f"VEC{len(values[0])}", 34962)
                  for key, values in streams.items()}
    material = copy.deepcopy(reference)
    assert not any("Texture" in k for k in material["pbrMetallicRoughness"])
    assert not any("Texture" in k for k in material)
    def srgb_byte(linear):
        srgb = 12.92 * linear if linear <= 0.0031308 else 1.055 * linear ** (1 / 2.4) - 0.055
        return round(max(0, min(1, srgb)) * 255)

    def png_chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    pixels = bytes(srgb_byte(c) for _, color in needles for c in color[:3])
    png = (b"\x89PNG\r\n\x1a\n"
           + png_chunk(b"IHDR", struct.pack(">IIBBBBB", len(needles), 1, 8, 2, 0, 0, 0))
           + png_chunk(b"IDAT", zlib.compress(b"\0" + pixels))
           + png_chunk(b"IEND", b""))
    binary.extend(b"\0" * (-len(binary) % 4))
    doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(png)})
    binary.extend(png)
    doc.setdefault("images", []).append({"bufferView": len(doc["bufferViews"]) - 1, "mimeType": "image/png"})
    doc.setdefault("samplers", []).append({"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071})
    doc.setdefault("textures", []).append({"source": len(doc["images"]) - 1, "sampler": len(doc["samplers"]) - 1})
    material["name"] = "MobileShrubPalette" if shrub else "MobileNeedlesPalette"
    material["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, 1]
    material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(doc["textures"]) - 1}
    doc["materials"].append(material)
    doc["meshes"].append({"name": "MobileNeedlesMerged", "primitives": [{
        "attributes": attributes, "indices": append(indices, 5125, "SCALAR", 34963),
        "material": len(doc["materials"]) - 1}]})
    doc["nodes"] = retained + [{"mesh": len(doc["meshes"]) - 1, "name": "MobileNeedlesMerged"}]
    doc["scenes"][0]["nodes"] = list(range(len(doc["nodes"])))
    doc["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(doc, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    destination.write_bytes(struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(binary))
                           + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
                           + struct.pack("<II", len(binary), 0x004E4942) + binary)
    print(f"Palette surfaces: {len(needles)} -> 1; preserved triangles: {len(indices) // 3}")


if __name__ == "__main__":
    merge(Path(sys.argv[1]), Path(sys.argv[2]), shrub="--shrub" in sys.argv[3:])
