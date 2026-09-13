"""Original metal roof covers, plaster end walls and folded flashing.
Geometry follows the existing shared convex collision envelope. Blender Z-up
converts to Godot Y-up; roof UVs follow the downhill sheet direction in metres.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    return mat


def mesh_object(name, vertices, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def box(name, location, size, mat, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.y = -angle
    obj.data.materials.append(mat)
    return obj


for kind in ['gable', 'shed']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cover = material('RoofCover', (0.3, 0.34, 0.34))
    endwall = material('RoofEndWall', (0.4, 0.38, 0.34))
    trim = material('RoofFlashing', (0.12, 0.16, 0.17))
    section = [(-8.5, 0), (0, 1.7), (8.5, 0)] if kind == 'gable' else [(-8.5, 0), (8.5, 1.2), (8.5, 0)]
    vertices = [(x, y, z) for y in [-7, 7] for x, z in section]
    faces = []
    for i in range(2 if kind == 'gable' else 1):
        faces.append((i, i+1, i+4, i+3))
    mesh_object('Sheet surfaces', vertices, faces, cover)
    walls = [(2, 1, 0), (3, 4, 5)]
    if kind == 'shed':
        walls.append((2, 5, 4, 1))
    mesh_object('Gable end walls', vertices, walls, endwall)
    for i in range(2 if kind == 'gable' else 1):
        x0, z0 = section[i]
        x1, z1 = section[i+1]
        length = math.hypot(x1-x0, z1-z0)
        angle = math.atan2(z1-z0, x1-x0)
        for j in range(25):
            box('Standing seam', ((x0+x1)/2, -6.9+j*0.575, (z0+z1)/2+0.025),
                (length, 0.025, 0.045), cover, angle)
        # Narrow folded rake flashing follows the sloped front/back outline.
        for y in [-7, 7]:
            box('Rake flashing', ((x0+x1)/2, y, (z0+z1)/2+0.012),
                (length, 0.045, 0.10), trim, angle)
    if kind == 'gable':
        for side in [-1, 1]:
            angle = -side * math.atan2(1.7, 8.5)
            box('Ridge cap', (side*0.09, 0, 1.725), (0.20, 14.04, 0.025), trim, angle)
    else:
        box('High edge cap', (8.48, 0, 1.22), (0.10, 14.04, 0.055), trim)
    # Shallow U-shaped eaves gutters, with open top and capped ends.
    for x in ([-8.53, 8.53] if kind == 'gable' else [-8.53]):
        vertices, faces = [], []
        for y in [-7, 7]:
            for step in range(9):
                angle = math.pi + step*math.pi/8
                vertices.append((x+math.cos(angle)*0.075, y, math.sin(angle)*0.075))
        for step in range(8):
            faces.append((step, step+1, step+10, step+9))
        faces.extend([tuple(reversed(range(9))), tuple(range(9, 18))])
        obj = mesh_object('Eaves gutter', vertices, faces, trim)
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new('Folded metal thickness', 'SOLIDIFY')
        modifier.thickness = 0.006
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Join by material, keeping the plaster ends separate from metal surfaces.
    for mat in [cover, endwall, trim]:
        objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.data.materials[0] == mat]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = mat.name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        # Top sheets: U across the building, V down the slope. Other faces
        # use dominant-axis projection. All coordinates retain metre scale.
        uv = obj.data.uv_layers.new(name='RoofUV')
        for polygon in obj.data.polygons:
            if abs(polygon.normal.z) > 0.5:
                axes = (1, 0)
            elif abs(polygon.normal.x) > 0.5:
                axes = (1, 2)
            else:
                axes = (0, 2)
            for loop in polygon.loop_indices:
                p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                uv.data[loop].uv = (p[axes[0]], p[axes[1]])
        # Some boxes bring an old default UV layer; export the metre UVs first.
        for layer in list(obj.data.uv_layers):
            if layer.name != 'RoofUV':
                obj.data.uv_layers.remove(layer)
        obj.data.uv_layers.active_index = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / f'art/roof_{kind}.blend'), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / f'client/assets/realism/roof_{kind}.glb'),
                             export_format='GLB', export_apply=True)
    print('ROOF_ASSET_PASS', kind)
