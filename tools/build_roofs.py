"""Original metal roof shells with standing seams, in world metre units."""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[1]
for kind in ["gable", "shed"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if kind == "gable":
        section = [(-8.5, 0), (0, 1.7), (8.5, 0)]
    else:
        section = [(-8.5, 0), (8.5, 1.2), (8.5, 0)]
    # Blender Z-up converts to Godot Y-up at export.
    vertices = [(x, y, z) for y in [-7, 7] for x, z in section]
    count = len(section)
    faces = []
    for i in range(count - 1):
        faces.append((i, i + 1, count + i + 1, count + i))
    faces += [tuple(reversed(range(count))), tuple(range(count, 2 * count)),
              (0, count, 2 * count - 1, count - 1)]
    mesh = bpy.data.meshes.new("Roof shell")
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new("RoofShell", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Recalculate closed shell normals before exporting.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    for i in range(count - 1):
        x0, z0 = section[i]
        x1, z1 = section[i + 1]
        if x0 == x1:
            continue
        length = math.hypot(x1 - x0, z1 - z0)
        angle = math.atan2(z1 - z0, x1 - x0)
        for j in range(25):
            bpy.ops.mesh.primitive_cube_add(size=1, location=((x0+x1)/2, -6.9+j*0.575, (z0+z1)/2+0.025))
            seam = bpy.context.object
            seam.dimensions = (length, 0.025, 0.045)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            seam.rotation_euler.y = -angle
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / f'art/roof_{kind}.blend'), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT / f'client/assets/realism/roof_{kind}.glb'),
                             export_format='GLB', export_apply=True)
