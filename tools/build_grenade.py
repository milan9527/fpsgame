"""Original low-poly fragmentation grenade, exported from Blender to Godot."""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, color, metallic=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = 0.6
    return result


olive = mat('Frag / olive enamel', (0.22, 0.29, 0.13), 0.35)
steel = mat('Frag / steel lever', (0.12, 0.16, 0.17), 0.75)
marking = mat('Frag / identification band', (0.75, 0.56, 0.19), 0.2)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.105)
body = bpy.context.object
body.name = 'Fragmentation body'
body.scale.z = 1.17
body.data.materials.append(olive)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for z in [-0.065, 0, 0.065]:
    bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4,
                                   major_radius=0.106 * math.sqrt(1 - (z / 0.123) ** 2),
                                   minor_radius=0.005, location=(0, 0, z))
    bpy.context.object.data.materials.append(marking if z == 0 else steel)
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.034, depth=0.052, location=(0, 0, 0.13))
bpy.context.object.data.materials.append(steel)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.065, 0, 0.06))
lever = bpy.context.object
lever.name = 'Safety lever'
lever.dimensions = (0.025, 0.042, 0.18)
lever.rotation_euler.y = 0.42
lever.data.materials.append(steel)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.mesh.primitive_torus_add(major_segments=12, minor_segments=4, major_radius=0.026,
                               minor_radius=0.004, location=(0, 0.047, 0.145), rotation=(math.pi / 2, 0, 0))
bpy.context.object.data.materials.append(steel)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art/grenade.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'client/assets/grenade.glb'), export_format='GLB', use_selection=True)
print('GRENADE_ASSET_BUILT')
