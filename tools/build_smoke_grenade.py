"""Original smoke canister with color band and lever; Blender source and GLB."""
import bpy
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = 0.65
    return mat

body_mat = material('Smoke / pale enamel', (0.58, 0.68, 0.62), 0.2)
band_mat = material('Smoke / white band', (0.92, 0.95, 0.91))
steel = material('Smoke / steel lever', (0.14, 0.18, 0.18), 0.7)
for z, radius, height, mat in [(0, 0.07, 0.20, body_mat), (0, 0.071, 0.035, band_mat), (0.11, 0.04, 0.025, steel)]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=height, location=(0, 0, z))
    bpy.context.object.data.materials.append(mat)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.065, 0, 0.04))
lever = bpy.context.object
lever.dimensions = (0.025, 0.035, 0.19)
lever.rotation_euler.y = 0.22
lever.data.materials.append(steel)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.join()
bpy.context.object.name = 'Smoke canister'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art/smoke_grenade.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'client/assets/smoke_grenade.glb'), export_format='GLB', use_selection=True)
print('SMOKE_GRENADE_ASSET_BUILT')
