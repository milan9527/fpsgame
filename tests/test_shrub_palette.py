"""Verify every shrub triangle and normal survives the Android palette merge."""
import json
from pathlib import Path
import struct
import unittest

ASSETS = Path(__file__).resolve().parents[1] / "client/assets/realism"


def geometry(name):
    raw = (ASSETS / (name + ".glb")).read_bytes()
    length = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + length])
    binary = raw[28 + length:]

    def read(index):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        width = {"SCALAR": 1, "VEC3": 3}[accessor["type"]]
        fmt = "<" + {5123: "H", 5125: "I", 5126: "f"}[accessor["componentType"]] * width
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, binary, start + i * stride)
                for i in range(accessor["count"])]

    triangles = []
    surfaces = 0
    for node_index in doc["scenes"][0]["nodes"]:
        node = doc["nodes"][node_index]
        assert set(node) <= {"mesh", "name"}
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            surfaces += 1
            positions = read(primitive["attributes"]["POSITION"])
            normals = read(primitive["attributes"]["NORMAL"])
            triangles.extend((positions[i], normals[i]) for (i,) in read(primitive["indices"]))
    return triangles, surfaces


class ShrubPaletteTest(unittest.TestCase):
    def test_preserves_all_triangle_vertices_and_normals(self):
        for original, candidate in [
            ("verge_shrub", "verge_shrub_palette_mobile"),
            ("verge_fine_shrub_mobile", "verge_fine_shrub_palette_mobile"),
        ]:
            with self.subTest(model=original):
                before, before_surfaces = geometry(original)
                after, after_surfaces = geometry(candidate)
                self.assertEqual(before_surfaces, 5)
                self.assertEqual(after_surfaces, 1)
                self.assertEqual(before, after)


if __name__ == "__main__":
    unittest.main()
