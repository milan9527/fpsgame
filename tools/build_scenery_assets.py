"""Normalize licensed scenery meshes while preserving their photographic textures."""
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
for source, name in [('wooden_military_crate', 'supply_crate'), ('boulder_01', 'boulder')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'artifacts/realism-sources' / source / 'model.gltf'))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1: bpy.ops.object.join()
    obj = bpy.context.object;obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    minimum = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    maximum = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    extent = maximum - minimum
    origin = Vector(((minimum.x+maximum.x)/2,(minimum.y+maximum.y)/2,minimum.z))
    target = Vector((2.5,2.0,1.5)) if name == 'supply_crate' else extent / max(extent)
    for vertex in obj.data.vertices:
        vertex.co -= origin
        for axis in range(3):vertex.co[axis] *= target[axis]/extent[axis]
    if name == 'boulder':
        edit = bmesh.new()
        edit.from_mesh(obj.data)
        bmesh.ops.remove_doubles(edit, verts=list(edit.verts), dist=0.00001)
        edit.to_mesh(obj.data)
        edit.free()
    triangles = sum(len(p.vertices)-2 for p in obj.data.polygons)
    if triangles > 12000:
        modifier = obj.modifiers.new('Static scenery budget','DECIMATE');modifier.ratio = 12000/triangles
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    assert sum(len(p.vertices)-2 for p in obj.data.polygons) <= 12000, name
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art'/(name+'.blend')),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/realism'/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
    print('SCENERY_ASSET',name,'triangles',sum(len(p.vertices)-2 for p in obj.data.polygons))
