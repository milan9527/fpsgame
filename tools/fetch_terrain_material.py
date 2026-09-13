"""Fetch seamless CC0 rock maps for the terrain slope material."""
import json
from concurrent.futures import ThreadPoolExecutor
import httpx
from fetch_scenery_assets import ROOT, fetch

asset = "rock_face_03"
response = httpx.get("https://api.polyhaven.com/files/" + asset, timeout=60)
response.raise_for_status()
catalog = response.json()
maps = {name: catalog[key]["2k"]["jpg"] for name, key in [
    ("albedo", "Diffuse"), ("normal", "nor_gl"), ("roughness", "Rough")]}
with ThreadPoolExecutor(max_workers=3) as pool:
    futures = [pool.submit(fetch, entry, ROOT / f"client/assets/realism/terrain_rock_{name}.jpg")
               for name, entry in maps.items()]
    for future in futures:
        future.result()
response = httpx.get("https://api.polyhaven.com/info/" + asset, timeout=60)
response.raise_for_status()
path = ROOT / "client/assets/realism/SOURCES.json"
manifest = json.loads(path.read_text())
manifest = [entry for entry in manifest if entry["asset"] != asset]
manifest.append({"asset": asset, "page": "https://polyhaven.com/a/" + asset,
                 "license": "CC0-1.0", "authors": response.json().get("authors", {}),
                 "files": maps, "modification": "Original 2K seamless maps for slope-blended background terrain."})
path.write_text(json.dumps(manifest, indent=2) + "\n")
print("TERRAIN_ROCK_READY")
