"""Original shallow warehouse facade assemblies, dimensions in metres.
Blender coordinates are authored through a Godot XYZ adapter. Closed louvers
and sheet cladding sit against the existing opaque wall collision surfaces.
"""
from pathlib import Path
import bpy
from math import radians

ROOT = Path(__file__).resolve().parents[1]


def material(name, color, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.78
    shader.inputs['Metallic'].default_value = metallic
    return mat


def box(name, at, size, mat, bevel=0.008):
    x, y, z = at
    sx, sy, sz = size
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -z, y))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (sx, sz, sy)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new('Edge radius', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier = obj.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Metre-based UVs for scanned concrete, independent of each member's size.
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        axes = sorted(range(3), key=lambda axis: abs(polygon.normal[axis]))[:2]
        for loop in polygon.loop_indices:
            p = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[axes[0]], p[axes[1]])
    return obj


for style in range(3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    concrete = material('FacadeConcrete', (0.34, 0.35, 0.32))
    steel = material('FacadeSteel', [(0.15, 0.19, 0.20), (0.23, 0.28, 0.26), (0.21, 0.22, 0.20)][style], 0.45)
    dark = material('FacadeVentBack', (0.028, 0.032, 0.030))
    for side in [-1, 1]:
        wall_x = side * 8.285
        for z in [-6.30, -2.1, 2.1, 6.30]:
            box('Concrete pier', (wall_x, 2.0, z), (0.10, 3.8, 0.28), concrete)
        box('Concrete lintel', (wall_x, 3.78, 0), (0.105, 0.24, 12.9), concrete)
        box('Concrete plinth', (wall_x, 0.48, 0), (0.105, 0.54, 12.9), concrete)
        for center_z in [-4.2, 0.0, 4.2]:
            if style == 1:
                # Folded vertical steel sheet, true small ribs instead of a
                # stretched flat wall. Each bay remains inside the wall bounds.
                vertices, faces = [], []
                for i in range(97):
                    z = center_z - 1.93 + i * 3.86 / 96
                    depth = [0, 0, 0.025, 0.025][i % 4]
                    x = side * (8.263 + depth)
                    vertices.extend([(x, -z, 0.78), (x, -z, 3.65)])
                for i in range(96):
                    a = i * 2
                    face = (a, a + 2, a + 3, a + 1)
                    faces.append(face if side < 0 else tuple(reversed(face)))
                mesh = bpy.data.meshes.new('Folded sheet')
                mesh.from_pydata(vertices, [], faces)
                mesh.update()
                uv = mesh.uv_layers.new(name='UVMap')
                for polygon in mesh.polygons:
                    for loop in polygon.loop_indices:
                        p = mesh.vertices[mesh.loops[loop].vertex_index].co
                        uv.data[loop].uv = (-p.y, p.z)
                obj = bpy.data.objects.new('Steel infill', mesh)
                bpy.context.collection.objects.link(obj)
                obj.data.materials.append(steel)
            else:
                # A closed industrial ventilation cassette, not a fake open
                # window that would disagree with the underlying solid wall.
                x = side * 8.31
                y = 2.72 if style == 0 else 2.45
                width = 1.9 if style == 0 else 2.7
                height = 0.64 if style == 0 else 0.88
                box('Vent back', (x, y, center_z), (0.015, height, width), dark, 0)
                for z in [center_z - width/2, center_z + width/2]:
                    box('Vent jamb', (side * 8.335, y, z), (0.06, height + 0.08, 0.055), steel)
                for edge_y in [y - height/2, y + height/2]:
                    box('Vent rail', (side * 8.335, edge_y, center_z), (0.06, 0.055, width), steel)
                for i in range(8):
                    slat = box('Louver blade', (side * 8.345, y - height/2 + (i + 0.5)*height/8, center_z),
                               (0.018, height/8 * 0.72, width - 0.06), steel, 0.002)
                    slat.rotation_euler.y = radians(side * 32)
    # Combine by material to keep three or fewer draw surfaces per warehouse.
    for mat in [concrete, steel, dark]:
        objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.data.materials[0] == mat]
        if not objects:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        bpy.context.object.name = mat.name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / f'art/facade_{style}.blend'), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / f'client/assets/realism/facade_{style}.glb'),
                             export_format='GLB', export_apply=True)
    triangles = sum(sum(len(p.vertices)-2 for p in obj.data.polygons)
                    for obj in bpy.context.scene.objects if obj.type == 'MESH')
    print(f'FACADE_ASSET_PASS style={style} triangles={triangles}')
