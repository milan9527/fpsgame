"""Original first-person sleeves/gloves and skeletal actions, in weapon-local meters."""
import bpy
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def v(x, y, z):
    # Godot coordinates -> Blender coordinates.
    return Vector((x, -z, y))

def material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*rgb, 1)
    mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.8
    return mat

cloth = material('Field sleeves', (0.19, 0.30, 0.27))
glove = material('Reinforced gloves', (0.055, 0.075, 0.08))
patch = material('Wrist straps', (0.40, 0.45, 0.32))
rest = {'Root': v(0,0,0), 'Up': v(0,0.1,0),
        'Elbow.L': v(-0.48,-0.38,0.48), 'Wrist.L': v(-0.055,-0.065,-0.18), 'Tip.L': v(0.015,-0.05,-0.2),
        'Elbow.R': v(0.28,-0.35,0.48), 'Wrist.R': v(0.015,-0.125,0.095), 'Tip.R': v(0.015,-0.08,0.06)}
bones = [('Root','Root','Up',None)]
for side in ['L','R']:
    bones += [(f'Forearm.{side}',f'Elbow.{side}',f'Wrist.{side}','Root'),
              (f'Hand.{side}',f'Wrist.{side}',f'Tip.{side}',f'Forearm.{side}')]
rig = bpy.data.objects.new('FirstPersonRig', bpy.data.armatures.new('FirstPersonSkeleton'))
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,start,end,parent in bones:
    bone = rig.data.edit_bones.new(name)
    bone.head, bone.tail = rest[start], rest[end]
    if parent:
        bone.parent = rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

def skin(obj, bone, mat):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('Arm skin', 'ARMATURE').object = rig
    obj.parent = rig

for side in ['L','R']:
    start, end = rest[f'Elbow.{side}'], rest[f'Wrist.{side}']
    direction = end-start
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.085, radius2=0.045, depth=direction.length*0.91, location=(start+end)/2)
    sleeve = bpy.context.object
    sleeve.name = f'Sleeve.{side}'
    sleeve.rotation_mode = 'QUATERNION'
    sleeve.rotation_quaternion = Vector((0,0,1)).rotation_difference(direction.normalized())
    skin(sleeve, f'Forearm.{side}', cloth)
    # A distinct cuff, palm, thumb and four curled fingers remain visible up close.
    for name, offset, size, mat in [
        ('Cuff', v(0,-0.008,0.025), (0.10,0.055,0.055), patch),
        ('Palm', v(0,0,-0.018), (0.083,0.055,0.085), glove),
        ('Thumb', v(-0.043 if side=='R' else 0.045,0.018,-0.036), (0.027,0.028,0.06), glove),
    ] + [(f'Finger{i}', v((i-1.5)*0.021,0.024,-0.062), (0.018,0.045,0.035), glove) for i in range(4)]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=end+offset)
        obj=bpy.context.object
        obj.name=f'{name}.{side}'
        obj.dimensions=(size[0],size[2],size[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bevel=obj.modifiers.new('Soft glove edges','BEVEL')
        bevel.width=0.006
        bevel.segments=2
        skin(obj, f'Hand.{side}', mat)

bpy.ops.object.select_all(action='DESELECT')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join()
bpy.context.object.name='FirstPersonSkin'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
rig.animation_data_create()
bpy.context.scene.render.fps=30
for clip in ['Hold','Reload','Throw','Heal']:
    action=bpy.data.actions.new(clip)
    rig.animation_data.action=action
    for frame in range(0,61,2):
        t=frame/60
        points={k:value.copy() for k,value in rest.items()}
        offsets={'L':Vector(), 'R':Vector()}
        if clip=='Reload':
            # Move the support hand to the magazine, draw it down, then reseat.
            reach=math.sin(math.pi*t)**0.6
            offsets['L']=v(0.07*reach, -0.27*math.sin(math.pi*t)**2, 0.18*reach)
        elif clip=='Throw':
            # Release is authoritative at action start; this is the follow-through.
            reach=max(0,1-t*1.4)
            offsets['R']=v(-0.1*reach,0.3*reach,-0.38*reach)
            offsets['L']=v(-0.18*reach,-0.1*reach,0.08*reach)
        elif clip=='Heal':
            reach=math.sin(math.pi*t)**0.6
            offsets['L']=v(0.23*reach,-0.08*reach,0.21*reach)
            offsets['R']=v(-0.08*reach,0.03*reach,-0.03*reach)
        for side in ['L','R']:
            points[f'Wrist.{side}']+=offsets[side]
            points[f'Tip.{side}']+=offsets[side]
        for name,start,end,parent in bones:
            pose=rig.pose.bones[name]
            old=(rest[end]-rest[start]).normalized()
            new=(points[end]-points[start]).normalized()
            orientation=old.rotation_difference(new) @ pose.bone.matrix_local.to_quaternion()
            stretch=(points[end]-points[start]).length/(rest[end]-rest[start]).length if name.startswith('Forearm') else 1
            pose.matrix=Matrix.LocRotScale(points[start],orientation,Vector((1,stretch,1)))
            bpy.context.view_layer.update()
            pose.rotation_mode='QUATERNION'
            for prop in ['location','rotation_quaternion','scale']:
                pose.keyframe_insert(prop,frame=frame,group=name)
    for curve in action.fcurves:
        for key in curve.keyframe_points: key.interpolation='LINEAR'
    track=rig.animation_data.nla_tracks.new()
    track.name=clip
    track.strips.new(clip,0,action)
    track.mute=True
    rig.animation_data.action=None
rig.animation_data.action=bpy.data.actions['Hold']
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/first_person.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/first_person.glb'),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
print('VIEWMODEL_ASSET_PASS bones=5 clips=Hold,Reload,Throw,Heal skinned_mesh=1')
