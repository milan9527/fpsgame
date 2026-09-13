"""Preserve every fir needle while reducing its two-quad ribbon to a kite.
Run with a Python environment containing numpy and scipy before build_fir_lod.py.
Inputs are the CC0 variant B files downloaded by fetch_tree_variant.py.
"""
from copy import deepcopy
import json
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/realism-sources/tree-b'
source = json.loads((SOURCE / 'tree.gltf').read_text())
data = (SOURCE / 'tree.bin').read_bytes()

def read(index):
    accessor = source['accessors'][index]
    view = source['bufferViews'][accessor['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
    dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[accessor['componentType']]
    return np.frombuffer(data, dtype=dtype, count=accessor['count'] * width,
                         offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0)).reshape(-1, width)

primitive = next(p for p in source['meshes'][0]['primitives']
                 if source['materials'][p['material']]['name'] == 'fir_tree_01_twig')
positions = read(primitive['attributes']['POSITION'])
triangles = read(primitive['indices']).reshape(-1, 3)
unique, first, inverse = np.unique(positions, axis=0, return_index=True, return_inverse=True)
ids = inverse[triangles]
edges = np.concatenate([ids[:, [0, 1]], ids[:, [1, 2]], ids[:, [2, 0]]])
graph = coo_matrix((np.ones(len(edges), dtype=np.int8), (edges[:, 0], edges[:, 1])),
                   shape=(len(unique), len(unique))).tocsr()
count, labels = connected_components(graph, directed=False)
face_labels = labels[ids[:, 0]]
face_counts = np.bincount(face_labels, minlength=count)
vertex_counts = np.bincount(labels, minlength=count)
needles = (face_counts == 4) & (vertex_counts == 6)
# Group six vertices of each disconnected ribbon, then sort along its long axis.
vertices = np.flatnonzero(needles[labels])
vertices = vertices[np.argsort(labels[vertices], kind='stable')].reshape(-1, 6)
points = unique[vertices]
# Longest bounding-box axis is sufficient for the very slender source ribbons.
axis = np.argmax(np.ptp(points, axis=1), axis=1)
projection = np.take_along_axis(points, axis[:, None, None], axis=2)[:, :, 0]
order = np.argsort(projection, axis=1)
vertices = np.take_along_axis(vertices, order, axis=1)

def kite(values):
    ribbon = values[first[vertices]]
    return np.stack(((ribbon[:, 0] + ribbon[:, 1]) * .5, ribbon[:, 2],
                     (ribbon[:, 4] + ribbon[:, 5]) * .5, ribbon[:, 3]), axis=1)

kite_positions = kite(positions)
# Tapering the endpoints otherwise loses coverage even though every needle
# survives. Preserve each source ribbon's surface area by widening its middle.
original_area = np.linalg.norm(np.cross(unique[ids[:, 1]] - unique[ids[:, 0]],
                                       unique[ids[:, 2]] - unique[ids[:, 0]]), axis=1) * .5
needle_area = np.bincount(face_labels, weights=original_area, minlength=count)[needles]
new_area = sum(np.linalg.norm(np.cross(kite_positions[:, b] - kite_positions[:, a],
                                      kite_positions[:, c] - kite_positions[:, a]), axis=1) * .5
               for a, b, c in [(0, 1, 2), (0, 2, 3)])
width_scale = needle_area / np.maximum(new_area, 1e-12)
middle = (kite_positions[:, 1] + kite_positions[:, 3]) * .5
for corner in [1, 3]:
    kite_positions[:, corner] = middle + (kite_positions[:, corner] - middle) * width_scale[:, None]
kite_normals = kite(read(primitive['attributes']['NORMAL']))
kite_normals /= np.maximum(np.linalg.norm(kite_normals, axis=2, keepdims=True), 1e-10)
kite_uvs = kite(read(primitive['attributes']['TEXCOORD_0']))
kite_indices = np.tile(np.array([[0, 1, 2], [0, 2, 3]], dtype=np.uint32), (len(vertices), 1, 1))
kite_indices += (np.arange(len(vertices), dtype=np.uint32) * 4)[:, None, None]
flat_positions = kite_positions.reshape(-1, 3)
flat_normals = kite_normals.reshape(-1, 3)
faces = kite_indices.reshape(-1, 3)
cross = np.cross(flat_positions[faces[:, 1]] - flat_positions[faces[:, 0]],
                 flat_positions[faces[:, 2]] - flat_positions[faces[:, 0]])
flip = (cross * flat_normals[faces].mean(axis=1)).sum(axis=1) < 0
faces[flip] = faces[flip][:, [0, 2, 1]]
# Keep UV and normal data for branches; only needles get the special simplification.
stem_faces = triangles[~needles[face_labels]]
stem_vertices, stem_inverse = np.unique(stem_faces, return_inverse=True)
output = deepcopy(source)
extra = bytearray()

def add(array, kind, component=5126):
    while len(extra) % 4:
        extra.append(0)
    array = np.asarray(array, dtype='<f4' if component == 5126 else '<u4')
    if kind == 'SCALAR':
        array = array.reshape(-1)
    view = len(output['bufferViews'])
    output['bufferViews'].append({'buffer': 1, 'byteOffset': len(extra), 'byteLength': array.nbytes})
    extra.extend(array.tobytes())
    accessor = {'bufferView': view, 'componentType': component, 'count': len(array), 'type': kind}
    if kind == 'VEC3':
        accessor.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
    index = len(output['accessors'])
    output['accessors'].append(accessor)
    return index

parts = [p for p in output['meshes'][0]['primitives'] if p['material'] != primitive['material']]
for name, pos, normals, uv, indices in [
    ('fir_tree_01_needles', flat_positions, flat_normals, kite_uvs.reshape(-1, 2), faces.reshape(-1)),
    ('fir_tree_01_twig_branches', positions[stem_vertices], read(primitive['attributes']['NORMAL'])[stem_vertices],
     read(primitive['attributes']['TEXCOORD_0'])[stem_vertices], stem_inverse),
]:
    material = deepcopy(source['materials'][primitive['material']])
    material['name'] = name
    material['alphaMode'] = 'OPAQUE'  # RGB texture; silhouettes are explicit mesh geometry.
    material_index = len(output['materials'])
    output['materials'].append(material)
    parts.append({'attributes': {'POSITION': add(pos, 'VEC3'), 'NORMAL': add(normals, 'VEC3'),
                                 'TEXCOORD_0': add(uv, 'VEC2')},
                  'indices': add(indices, 'SCALAR', 5125), 'material': material_index})
output['meshes'][0]['primitives'] = parts
output['buffers'].append({'uri': 'needle-kites.bin', 'byteLength': len(extra)})
(SOURCE / 'needle-kites.bin').write_bytes(extra)
(SOURCE / 'needle-kites.gltf').write_text(json.dumps(output))
print(f'FIR_NEEDLES_PASS needles={len(vertices)} original_triangles={len(vertices)*4} kite_triangles={len(faces)} branch_triangles={len(stem_faces)}')
