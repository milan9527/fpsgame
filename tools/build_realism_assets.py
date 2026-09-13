"""Run with Blender --background --python; builds tree LODs and an original facade kit."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'client/assets/realism'


def save_scene(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'art' / (name + '.blend')), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')), export_format='GLB', use_selection=False, export_apply=True)


def material(name, color, metallic=0, roughness=0.75):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    return m


def box(name, at, size, mat, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier=obj.modifiers.new('Manufactured rounded edges','BEVEL');modifier.width=bevel;modifier.segments=2
    return obj


def main():
    import runpy
    runpy.run_path(str(ROOT / 'tools/build_tree_impostor.py'), run_name='__main__')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    frame=material('Aged painted steel',(0.23,0.27,0.24),0.5,0.6)
    rust=material('Oxidized fasteners',(0.18,0.085,0.035),0.15,0.9)
    dark=material('Closed shutter recess',(0.075,0.09,0.08),0.3,0.9)
    box('Closed shutter backing',(0,0,0),(1.75,0.04,1.0),dark)
    for x in [-0.9,0.9]:box('Side frame',(x,-0.04,0),(0.07,0.10,1.13),frame)
    for z in [-0.54,0.54]:box('Lintel frame',(0,-0.04,z),(1.85,0.10,0.07),frame)
    for z in range(9):
        slat=box('Ventilation louvre',(0,-0.07,-0.44+z*0.11),(1.72,0.045,0.08),frame,0.005);slat.rotation_euler.x=0.35
    for x in [-0.86,0.86]:
        for z in [-0.5,0.5]:
            bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=0.018,location=(x,-0.105,z));bpy.context.object.data.materials.append(rust)
    for obj in list(bpy.context.scene.objects):
        if obj.type == 'MESH':
            bpy.context.view_layer.objects.active=obj
            for modifier in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    bpy.ops.object.join()
    save_scene('shutter_panel')


if __name__=='__main__':main()
