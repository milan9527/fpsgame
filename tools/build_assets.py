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
    bsdf.inputs['Roughness'].default_value = 0.62 if metal else 0.88
    return m


steel = material('Graphite / parkerized steel', (0.025, 0.028, 0.027), 0.65)
polymer = material('Slate / composite', (0.035, 0.038, 0.030))
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


# A focused rebuild avoids changing unrelated weapon and effect assets.
if os.environ.get('ASSET_ONLY') == 'operator':
    exec(compile((ROOT / 'tools' / 'build_operator.py').read_text(), 'build_operator.py', 'exec'))
    raise SystemExit(0)

# Blender Z up, +Y forward exports to Godot -Z forward.
box('Upper receiver', (0, 0.015, 0), (0.10, 0.34, 0.11), steel)
box('Lower receiver', (0, -0.015, -0.065), (0.08, 0.23, 0.07), polymer)
def cylinder(name, at, radius, depth, mat, axis='Y'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=at)
    obj=bpy.context.object;obj.name=name
    if axis=='Y': obj.rotation_euler.x=math.pi/2
    elif axis=='X': obj.rotation_euler.y=math.pi/2
    obj.data.materials.append(mat)
    bevel=obj.modifiers.new('Turned edge', 'BEVEL');bevel.width=0.001;bevel.segments=2
    obj.modifiers.new('Machined normals','WEIGHTED_NORMAL')
    return obj

cylinder('Barrel', (0, 0.36, 0.015), 0.018, 0.38, steel)
for y in [0.32, 0.44, 0.51]: cylinder('Barrel collar',(0,y,0.015),0.022,0.015,steel)
# Recessed-looking side plates, charging handle and fasteners stay clear of the sight line.
for side in [-1,1]:
    box('Receiver inset',(side*0.051,-0.035,0.012),(0.004,0.15,0.046),polymer,0.002)
    for y in [-0.10,0.03]: cylinder('Receiver pin',(side*0.055,y,-0.008),0.006,0.004,steel,'X')
    for i in range(5):
        box('Handguard vent',(side*0.046,0.16+i*0.026,0.02),(0.003,0.016,0.021),steel,0.002)
box('Charging handle',(0,-0.13,0.044),(0.125,0.018,0.017),steel,0.003)
box('Trigger guard lower',(0,-0.055,-0.125),(0.022,0.074,0.013),steel,0.003)
box('Trigger guard front',(0,-0.016,-0.10),(0.022,0.013,0.055),steel,0.003)
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
cylinder('Optic windage turret', (0.044, -0.015, 0.128), 0.013, 0.017, polymer, 'X')
cylinder('Optic battery cap', (-0.044, -0.015, 0.128), 0.016, 0.014, steel, 'X')
for y in [-0.045, 0.015]:
    cylinder('Optic mount screw', (0.033, y, 0.085), 0.006, 0.012, steel, 'X')
for i in range(6):
    box('Rail_%02d' % i, (0, 0.10 + i * 0.032, 0.065), (0.09, 0.016, 0.012), steel, 0.003)
box('Identification plate', (0.052, -0.025, 0.015), (0.005, 0.07, 0.025), brass, 0.001)
def anchor(name, location):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location

def merge_weapon():
    parts = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH'
             and not obj.name.startswith(('Magazine', 'Butt'))]
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = 'WeaponBody'
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

anchor('SightAnchor', (0, -0.015, 0.13))
anchor('MuzzleAnchor', (0, 0.585, 0.015))
merge_weapon()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'carbine.glb'), export_format='GLB', use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'carbine.blend'))
if os.environ.get('ASSET_ONLY') == 'carbine':
    raise SystemExit(0)
exec(compile((ROOT / 'tools' / 'build_weapon_variants.py').read_text(), 'build_weapon_variants.py', 'exec'))
if os.environ.get('ASSET_ONLY') == 'weapons':
    raise SystemExit(0)

# The humanoid authoring script shares the material palette and mesh helpers.
exec(compile((ROOT / 'tools' / 'build_operator.py').read_text(), 'build_operator.py', 'exec'))
print('ASSETS_BUILT carbine.glb shotgun.glb marksman.glb operator.glb')

exec(compile((ROOT / 'tools' / 'build_grenade.py').read_text(), str(ROOT / 'tools' / 'build_grenade.py'), 'exec'))
exec(compile((ROOT / 'tools' / 'build_viewmodel.py').read_text(), str(ROOT / 'tools' / 'build_viewmodel.py'), 'exec'))
