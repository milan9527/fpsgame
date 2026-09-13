"""Blender: retain the source fir and render a matching distant billboard."""
import bpy, math
from mathutils import Vector
from pathlib import Path
r=Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(r/'artifacts/realism-sources/tree/tree.gltf'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();t=bpy.context.object
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
p=[v.co for v in t.data.vertices];lo=Vector(tuple(min(v[i] for v in p) for i in range(3)));hi=Vector(tuple(max(v[i] for v in p) for i in range(3)));c=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));s=9/(hi.z-lo.z)
for v in t.data.vertices:v.co=(v.co-c)*s
bpy.ops.export_scene.gltf(filepath=str(r/'client/assets/realism/fir_near.glb'),export_format='GLB',use_selection=True,export_apply=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(r/'art/realistic_fir.blend'),compress=True)
bpy.ops.object.camera_add(location=(0,-20,4.5));camera=bpy.context.object;camera.rotation_euler=(math.pi/2,0,0);camera.data.type='ORTHO';camera.data.ortho_scale=9.5;bpy.context.scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-6,-8,12));light=bpy.context.object;light.data.energy=1500;light.data.shape='DISK';light.data.size=8;light.rotation_euler=(Vector((0,0,4))-light.location).to_track_quat('-Z','Y').to_euler()
scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Ambient');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.72,.8,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True;scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100;scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard';scene.render.filepath=str(r/'client/assets/realism/fir_impostor.png');bpy.ops.render.render(write_still=True)
