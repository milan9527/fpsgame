"""Extract the fuller CC0 fir variant B for background canopy rendering."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import httpx

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "artifacts/realism-sources"
original = json.loads((source / "tree.gltf.json").read_text())
catalog = json.loads((source / "fir_tree_01.json").read_text())["gltf"]["1k"]["gltf"]
output = source / "tree-b"
output.mkdir(exist_ok=True)
mesh = deepcopy(original["meshes"][1])
accessors = sorted({i for p in mesh["primitives"] for i in [p["indices"], *p["attributes"].values()]})
views = sorted({original["accessors"][i]["bufferView"] for i in accessors})
amap = {old: new for new, old in enumerate(accessors)}
vmap = {old: new for new, old in enumerate(views)}
data, output_views, receipts = bytearray(), [], []
url = catalog["include"]["fir_tree_01.bin"]["url"]
for index in views:
    view = deepcopy(original["bufferViews"][index])
    start, size = view.get("byteOffset", 0), view["byteLength"]
    cached = output / f"range-{start}-{size}.bin"
    if not cached.exists():
        response = httpx.get(url, headers={"Range": f"bytes={start}-{start+size-1}"},
                             timeout=180, follow_redirects=True)
        response.raise_for_status()
        assert response.status_code == 206 and len(response.content) == size
        cached.write_bytes(response.content)
    block = cached.read_bytes()
    assert len(block) == size
    receipts.append({"offset": start, "length": size, "sha256": hashlib.sha256(block).hexdigest()})
    while len(data) % 4:
        data.append(0)
    view.update(buffer=0, byteOffset=len(data))
    data.extend(block)
    output_views.append(view)
new_accessors = [deepcopy(original["accessors"][i]) for i in accessors]
for accessor in new_accessors:
    accessor["bufferView"] = vmap[accessor["bufferView"]]
for primitive in mesh["primitives"]:
    primitive["indices"] = amap[primitive["indices"]]
    primitive["attributes"] = {k: amap[v] for k, v in primitive["attributes"].items()}
model = {k: deepcopy(original[k]) for k in ["asset", "materials", "textures", "images", "samplers"] if k in original}
for image in model["images"]:
    image["uri"] = "../tree/" + image["uri"]
model.update(scene=0, scenes=[{"nodes": [0]}], nodes=[{"name": "fir_source_b", "mesh": 0}],
             meshes=[mesh], accessors=new_accessors, bufferViews=output_views,
             buffers=[{"uri": "tree.bin", "byteLength": len(data)}])
(output / "tree.bin").write_bytes(data)
(output / "tree.gltf").write_text(json.dumps(model))
(output / "source.json").write_text(json.dumps({"url": url, "variant": "B", "ranges": receipts}, indent=2))
print("FIR_VARIANT_B_READY", len(data), "bytes")
