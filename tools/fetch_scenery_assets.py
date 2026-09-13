"""Fetch checksum-verified CC0 scenery meshes from Poly Haven."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import httpx

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ['wooden_military_crate', 'boulder_01', 'exterior_aircon_unit', 'industrial_wall_lamp', 'rollershutter_window_01']


def fetch(entry, path):
    if path.exists() and hashlib.md5(path.read_bytes()).hexdigest() == entry['md5']:
        return
    response = httpx.get(entry['url'], timeout=120, follow_redirects=True)
    response.raise_for_status()
    if hashlib.md5(response.content).hexdigest() != entry['md5']:
        raise ValueError('Checksum mismatch: ' + path.name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(response.content)


def main():
    manifest_path = ROOT / 'client/assets/realism/SOURCES.json'
    manifest = json.loads(manifest_path.read_text())
    for asset in ASSETS:
        response = httpx.get('https://api.polyhaven.com/files/' + asset, timeout=60)
        response.raise_for_status()
        model = response.json()['gltf']['1k']['gltf']
        source = ROOT / 'artifacts/realism-sources' / asset
        jobs = [(model, source / 'model.gltf')]
        jobs += [(entry, source / filename) for filename, entry in model['include'].items()]
        with ThreadPoolExecutor(max_workers=4) as pool:
            for future in [pool.submit(fetch, entry, path) for entry, path in jobs]: future.result()
        info = httpx.get('https://api.polyhaven.com/info/' + asset, timeout=60)
        info.raise_for_status()
        manifest = [entry for entry in manifest if entry['asset'] != asset]
        manifest.append({'asset': asset, 'page': 'https://polyhaven.com/a/' + asset,
                         'license': 'CC0-1.0', 'authors': info.json().get('authors', {}),
                         'source': model, 'modification': 'Normalized in Blender; static mesh triangle budget capped at 12000.'})
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__': main()
