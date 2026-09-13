"""Fetch selected CC0 Poly Haven sources with checksum validation; no game credentials."""
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import httpx
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'client/assets/realism'
SOURCE = ROOT / 'artifacts/realism-sources'
ASSETS = {'ground': 'aerial_grass_rock', 'plaster': 'grey_plaster_02', 'asphalt': 'asphalt_02', 'roof': 'corrugated_iron_02'}


def fetch(entry, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    r = httpx.get(entry['url'], timeout=180, follow_redirects=True)
    r.raise_for_status()
    assert hashlib.md5(r.content).hexdigest() == entry['md5'], target.name
    target.write_bytes(r.content)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE.mkdir(parents=True, exist_ok=True)
    for asset in ['fir_tree_01', 'kloofendal_48d_partly_cloudy_puresky']:
        response = httpx.get('https://api.polyhaven.com/files/' + asset, timeout=60)
        response.raise_for_status()
        (SOURCE / (asset + '.json')).write_text(response.text)
    sources, jobs = [], []
    for name, asset in ASSETS.items():
        r = httpx.get('https://api.polyhaven.com/files/' + asset, timeout=60); r.raise_for_status()
        files = r.json()
        resolution = "2k" if name in ["ground", "plaster"] else "1k"
        for kind, key in [('albedo', 'Diffuse'), ('normal', 'nor_gl'), ('roughness', 'Rough')]:
            entry = files[key][resolution]['jpg']
            jobs.append((entry, OUT / f'{name}_{kind}.jpg'))
        sources.append({'asset': asset, 'page': 'https://polyhaven.com/a/' + asset, 'license': 'CC0-1.0', 'files': {kind: files[key][resolution]['jpg'] for kind, key in [('albedo', 'Diffuse'), ('normal', 'nor_gl'), ('roughness', 'Rough')]}})
    sky = json.loads((SOURCE / 'kloofendal_48d_partly_cloudy_puresky.json').read_text())['tonemapped']
    jobs.append((sky, SOURCE / 'sky-original.jpg'))
    tree_info = json.loads((SOURCE / 'fir_tree_01.json').read_text())['gltf']['1k']['gltf']
    fetch(tree_info, SOURCE / 'tree.gltf.json')
    tree_dir = SOURCE / 'tree'
    for name, entry in tree_info['include'].items():
        if name.endswith('.jpg'): jobs.append((entry, tree_dir / name))
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = [pool.submit(fetch, entry, path) for entry, path in jobs]
        for result in futures: result.result()
    with Image.open(SOURCE / 'sky-original.jpg') as image:
        image.resize((2048, 1024), Image.Resampling.LANCZOS).save(OUT / 'sky.jpg', quality=92)
    original = json.loads((SOURCE / 'tree.gltf.json').read_text())
    # Extract only variant C (0.5M faces), not the 6.5M-face forest collection.
    mesh = deepcopy(original['meshes'][2])
    accessors = sorted({i for p in mesh['primitives'] for i in [p['indices'], *p['attributes'].values()]})
    views = sorted({original['accessors'][i]['bufferView'] for i in accessors})
    amap, vmap = {old: new for new, old in enumerate(accessors)}, {old: new for new, old in enumerate(views)}
    data, output_views = bytearray(), []
    binary_url = tree_info['include']['fir_tree_01.bin']['url']
    for old in views:
        view = deepcopy(original['bufferViews'][old]); start = view.get('byteOffset', 0); size = view['byteLength']
        r = httpx.get(binary_url, headers={'Range': f'bytes={start}-{start+size-1}'}, timeout=120)
        r.raise_for_status()
        assert r.status_code == 206 and len(r.content) == size
        while len(data) % 4: data.append(0)
        view['buffer'] = 0; view['byteOffset'] = len(data)
        data.extend(r.content); output_views.append(view)
    new_accessors = [deepcopy(original['accessors'][i]) for i in accessors]
    for accessor in new_accessors: accessor['bufferView'] = vmap[accessor['bufferView']]
    for primitive in mesh['primitives']:
        primitive['indices'] = amap[primitive['indices']]
        primitive['attributes'] = {k: amap[v] for k, v in primitive['attributes'].items()}
    model = {k: original[k] for k in ['asset', 'materials', 'textures', 'images', 'samplers'] if k in original}
    model.update({'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': 'fir_source_c', 'mesh': 0}], 'meshes': [mesh], 'accessors': new_accessors, 'bufferViews': output_views, 'buffers': [{'uri': 'tree.bin', 'byteLength': len(data)}]})
    (tree_dir / 'tree.bin').write_bytes(data)
    (tree_dir / 'tree.gltf').write_text(json.dumps(model))
    sources += [{'asset': 'fir_tree_01', 'page': 'https://polyhaven.com/a/fir_tree_01', 'license': 'CC0-1.0', 'source': tree_info['url'], 'modification': 'Variant C extracted and normalized in Blender; full geometry near, rendered billboard at distance.'}, {'asset': 'kloofendal_48d_partly_cloudy_puresky', 'page': 'https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky', 'license': 'CC0-1.0', 'source': sky, 'modification': 'Tonemapped panorama resized to 2048x1024.'}]
    (OUT / 'SOURCES.json').write_text(json.dumps(sources, indent=2) + '\n')
    print('CC0 textures downloaded; extracted tree bytes:', len(data))


if __name__ == '__main__':
    main()
