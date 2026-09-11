"""Author the original two-seat buggy. Blender Z-up, +Y forward -> Godot -Z."""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


def material(name, color, metal=0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1)
    value.use_nodes = True
    shader = value.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.7
    return value


paint = material("Buggy / field green", (0.22, 0.31, 0.24), 0.3)
frame = material("Buggy / tubular frame", (0.055, 0.075, 0.08), 0.7)
rubber = material("Buggy / tires", (0.025, 0.035, 0.035))
seat = material("Buggy / seat fabric", (0.12, 0.16, 0.15))
lamp = material("Buggy / lamp lens", (0.85, 0.8, 0.55))


def box(name, position, size, surface):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(surface)
    bevel = obj.modifiers.new("Rounded edge", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def bar(name, start, end, radius=0.035):
    delta = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=delta.length,
                                       location=(Vector(start) + Vector(end)) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(frame)
    return obj


box("Chassis", (0, 0, 0.57), (1.52, 3.1, 0.22), frame)
box("Hood", (0, 1.03, 0.93), (1.48, 0.8, 0.35), paint)
box("Rear engine cover", (0, -1.02, 0.83), (1.45, 0.64, 0.35), paint)
for side in (-1, 1):
    x = side * 0.43
    box("Seat cushion", (x, -0.1, 0.83), (0.58, 0.64, 0.17), seat)
    back = box("Seat back", (x, -0.43, 1.12), (0.58, 0.15, 0.68), seat)
    back.rotation_euler.x = -0.12
    box("Headrest", (x, -0.49, 1.52), (0.31, 0.16, 0.21), seat)
    box("Side sill", (side * 0.77, -0.15, 0.72), (0.1, 1.7, 0.25), paint)
    bar("Front roll upright", (side * 0.72, 0.72, 0.65), (side * 0.69, 0.34, 1.74))
    bar("Rear roll upright", (side * 0.72, -0.85, 0.62), (side * 0.69, -0.68, 1.74))
    bar("Roof side rail", (side * 0.69, 0.34, 1.74), (side * 0.69, -0.68, 1.74))
    for y in (-1.2, 1.2):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.43, depth=0.25,
                                           location=(side * 0.8, y, 0.43),
                                           rotation=(0, math.pi / 2, 0))
        wheel = bpy.context.object
        wheel.name = ("Wheel_F" if y > 0 else "Wheel_R") + ("L" if side < 0 else "R")
        wheel.data.materials.append(rubber)
        bar("Wheel hub", (side * 0.65, y, 0.43), (side * 0.94, y, 0.43), 0.18)
    box("Headlight", (side * 0.52, 1.48, 0.93), (0.23, 0.09, 0.16), lamp)
for y in (0.34, -0.68):
    bar("Roof cross rail", (-0.69, y, 1.74), (0.69, y, 1.74))
for y in (-1.68, 1.68):
    bar("Bumper", (-0.78, y, 0.53), (0.78, y, 0.53), 0.065)
bar("Steering column", (-0.43, 0.33, 0.91), (-0.43, 0.18, 1.19), 0.035)
bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=8, location=(-0.43, 0.18, 1.19),
                                rotation=(math.radians(55), 0, 0), major_radius=0.18, minor_radius=0.025)
bpy.context.object.name = "Steering wheel"
bpy.context.object.data.materials.append(frame)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/buggy.blend"))
bpy.ops.export_scene.gltf(filepath=str(ROOT / "client/assets/buggy.glb"), export_format="GLB",
                         export_apply=True, export_yup=True)
print("BUGGY_ASSET_BUILT seats=2 wheels=4 original_geometry=ok")
