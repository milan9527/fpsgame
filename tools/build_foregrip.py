"""Original rail-mounted vertical foregrip, authored in metres with Blender."""
import bpy
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .7
    node.inputs['Metallic'].default_value = metallic
    return mat

polymer = material('Foregrip / olive polymer', (.18, .23, .16))
steel = material('Foregrip / rail clamp', (.08, .10, .11), .65)

def box(name, at, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new('Rounded polymer edges', 'BEVEL')
    bevel.width = .005
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj

box('Rail clamp', (0, 0, -.012), (.060, .080, .024), steel)
box('Vertical grip', (0, -.004, -.082), (.044, .052, .120), polymer)
box('Flared base', (0, -.004, -.143), (.054, .062, .014), polymer)
for i in range(5):
    box('Grip rib', (0, -.004, -.045-i*.018), (.048, .056, .005), steel)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.join()
bpy.context.object.name = 'Vertical foregrip'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/foregrip.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/foregrip.glb'), export_format='GLB', use_selection=True)
print('FOREGRIP_ASSET_BUILT')
