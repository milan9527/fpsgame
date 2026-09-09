"""Reproducible original Blender asset authoring. Run with Blender --background --python."""
import bpy
import math
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'client' / 'assets'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'art'
SOURCE.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, metal=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metal
    bsdf.inputs['Roughness'].default_value = 0.4 if metal else 0.8
    return m


steel = material('Graphite / parkerized steel', (0.055, 0.085, 0.10), 0.7)
polymer = material('Slate / composite', (0.11, 0.18, 0.19))
brass = material('Sand / markings', (0.75, 0.55, 0.25), 0.4)
cloth = material('Ranger / field uniform', (0.29, 0.38, 0.29))
armor = material('Ranger / armor', (0.14, 0.21, 0.22))
visor = material('Ranger / visor', (0.06, 0.12, 0.15), 0.6)


def box(name, loc, scale, mat, bevel=0.012):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        mod = o.modifiers.new('Machined edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o


# Blender Z up, +Y forward exports to Godot -Z forward.
box('Upper receiver', (0, 0.015, 0), (0.10, 0.34, 0.11), steel)
box('Lower receiver', (0, -0.015, -0.065), (0.08, 0.23, 0.07), polymer)
box('Barrel', (0, 0.36, 0.015), (0.043, 0.38, 0.043), steel)
box('Hand guard', (0, 0.225, 0), (0.09, 0.19, 0.10), polymer)
box('Muzzle brake', (0, 0.55, 0.015), (0.064, 0.065, 0.065), steel)
box('Magazine', (0, 0.01, -0.17), (0.065, 0.105, 0.20), steel).rotation_euler.x = -0.12
box('Pistol grip', (0, -0.115, -0.15), (0.07, 0.075, 0.17), polymer).rotation_euler.x = 0.2
box('Butt stock', (0, -0.27, -0.025), (0.08, 0.23, 0.14), polymer)
box('Butt plate', (0, -0.4, -0.025), (0.10, 0.04, 0.17), steel)
box('Optic base', (0, -0.015, 0.09), (0.055, 0.10, 0.055), steel)
box('Optic hood L', (-0.031, -0.015, 0.13), (0.012, 0.065, 0.065), steel)
box('Optic hood R', (0.031, -0.015, 0.13), (0.012, 0.065, 0.065), steel)
box('Optic top', (0, -0.015, 0.162), (0.07, 0.065, 0.012), steel)
for i in range(6):
    box('Rail_%02d' % i, (0, 0.10 + i * 0.032, 0.065), (0.09, 0.016, 0.012), steel, 0.003)
box('Identification plate', (0.052, -0.025, 0.015), (0.005, 0.07, 0.025), brass, 0.001)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'carbine.glb'), export_format='GLB', use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'carbine.blend'))
bpy.ops.object.delete(use_global=False)

# Humanoid mesh assembled from original low-poly armor pieces.
box('Torso armor', (0, 0, 1.16), (0.60, 0.32, 0.53), armor, 0.055)
box('Pelvis', (0, 0, 0.80), (0.44, 0.30, 0.24), cloth, 0.04)
for side in [-1, 1]:
    box('Leg', (side * 0.145, 0, 0.44), (0.22, 0.25, 0.64), cloth, 0.045)
    box('Boot', (side * 0.145, 0.06, 0.095), (0.24, 0.38, 0.19), steel, 0.02)
    box('Arm', (side * 0.39, 0, 1.10), (0.20, 0.23, 0.55), cloth, 0.045)
    box('Shoulder', (side * 0.37, 0, 1.35), (0.27, 0.30, 0.22), armor, 0.05)
    box('Pouch', (side * 0.15, 0.19, 1.09), (0.13, 0.10, 0.20), cloth, 0.012)
box('Helmet', (0, 0, 1.65), (0.40, 0.40, 0.34), armor, 0.09)
box('Visor', (0, 0.197, 1.65), (0.31, 0.02, 0.11), visor, 0.01)
box('Radio antenna', (0.26, -0.20, 1.45), (0.025, 0.025, 0.40), steel, 0.003)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'operator.glb'), export_format='GLB', use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'operator.blend'))
print('ASSETS_BUILT carbine.glb operator.glb')
