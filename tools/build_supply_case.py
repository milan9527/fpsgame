"""Original rugged supply case, normalized for the existing loot proxy dimensions."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metal=0):
    result=bpy.data.materials.new(name);result.use_nodes=True
    shader=result.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=metal
    shader.inputs['Roughness'].default_value=0.8
    return result

body=material('Supply body',(0.10,0.14,0.07))
rubber=material('Supply hardware',(0.018,0.023,0.016),0.3)
steel=material('Latch steel',(0.13,0.15,0.12),0.7)

def box(name, at, size, mat, bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    modifier=obj.modifiers.new('Molded radius','BEVEL');modifier.width=bevel;modifier.segments=3
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    modifier=obj.modifiers.new('Panel normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=modifier.name)

box('Lower shell',(0,0,-0.06),(0.95,0.95,0.84),body,0.065)
box('Lid seal',(0,0,0.36),(0.965,0.965,0.035),rubber,0.05)
box('Lid',(0,0,0.435),(0.97,0.97,0.12),body,0.035)
for x in [-0.43,0.43]:
    for y in [-0.43,0.43]:
        box('Corner protector',(x,y,-0.1),(0.14,0.14,0.76),rubber,0.035)
for x in [-0.28,0.28]:
    box('Latch',(x,-0.482,0.27),(0.105,0.032,0.17),steel,0.012)
    box('Hinge',(x,0.477,0.345),(0.14,0.042,0.10),rubber,0.012)
for x in [-0.15,0.15]:box('Handle mount',(x,-0.48,-0.01),(0.04,0.045,0.16),rubber,0.008)
box('Carry grip',(0,-0.50,-0.06),(0.32,0.04,0.055),rubber,0.012)
for x in [-0.30,-0.10,0.10,0.30]:box('Lid rib',(x,0,0.496),(0.04,0.74,0.014),rubber,0.004)
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.ops.object.join();bpy.context.object.name='SupplyCase'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/supply_case.blend'),compress=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/realism/supply_case.glb'),export_format='GLB',export_apply=True)
