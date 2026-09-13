"""Build a reduced fuller fir B from the retained CC0 authoring source.
Run prepare_fir_needles.py first, then Blender --background --python.
Never modifies the source Blend.
"""
from pathlib import Path
import json
import time
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
started = time.monotonic()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'artifacts/realism-sources/tree-b/needle-kites.gltf'))
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.ops.object.join()
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
tree = bpy.context.object
low = Vector(tuple(min(v.co[i] for v in tree.data.vertices) for i in range(3)))
high = Vector(tuple(max(v.co[i] for v in tree.data.vertices) for i in range(3)))
origin = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
for vertex in tree.data.vertices:
    vertex.co = (vertex.co - origin) * (9 / (high.z - low.z))
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='MATERIAL')
bpy.ops.object.mode_set(mode='OBJECT')
report = []
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH':
        continue
    # These source color attributes are not referenced by the materials.
    # Dropping them avoids padding millions of needle vertices with empty colors.
    while obj.data.color_attributes:
        obj.data.color_attributes.remove(obj.data.color_attributes[0])
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    name = obj.data.materials[0].name
    before = sum(len(p.vertices)-2 for p in obj.data.polygons)
    ratio = 1.0 if 'needles' in name else 0.1 if 'twig' in name else 0.25 if 'trunk' in name else 0.5
    print(f'FIR_REDUCE_START material={name} triangles={before} ratio={ratio}', flush=True)
    if ratio < 1.0:
        modifier = obj.modifiers.new('Runtime mesh reduction', 'DECIMATE')
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    after = sum(len(p.vertices)-2 for p in obj.data.polygons)
    obj.name = name
    report.append({'material': name, 'before': before, 'after': after})
    print(f'FIR_REDUCE_DONE material={name} triangles={after} elapsed={time.monotonic()-started:.1f}', flush=True)
bpy.ops.object.select_all(action='SELECT')
output = ROOT / 'client/assets/realism/fir_full.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_apply=True)
report_path = ROOT / 'artifacts/realism19-reduction.json'
report_path.write_text(json.dumps({'parts': report, 'seconds': time.monotonic()-started}, indent=2)+'\n')
print('FIR_LOD_BUILD_PASS', flush=True)
