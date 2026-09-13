"""Original rigid-panel humanoid skin and keyed locomotion clips, authored in Blender.
Executed by build_assets.py, which supplies materials, box(), OUT and SOURCE.
"""
import bpy
import math
from mathutils import Vector, Matrix

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def vec(x, y, z):
    return Vector((x, y, z))


def joint_between(start, end, length, bend):
    axis = end - start
    distance = axis.length
    axis.normalize()
    perpendicular = bend - axis * bend.dot(axis)
    perpendicular.normalize()
    return (start + end) * 0.5 + perpendicular * math.sqrt(max(0.001, length * length - distance * distance / 4))


def joints(crouch=0.0, phase=0.0, stride=0.0, lift=0.0, reload=0.0, jump=0.0, breath=0.0, death=0.0, downed=0.0, seated=0, slump=0):
    body = vec(0, -0.12 * crouch, -0.65 * crouch + breath)
    p = {'Root': vec(0, 0, 0), 'Hips': vec(0, 0, 0.94) + body,
         'Spine': vec(0, 0, 1.36) + body, 'Neck': vec(0, 0, 1.48) + body,
         'Head': vec(0, 0, 1.76) + body}
    for side, sign in [('L', -1), ('R', 1)]:
        step = phase + (math.pi if sign == 1 else 0)
        hip = vec(sign * 0.14, 0, 0.94) + body
        ankle = vec(sign * 0.14, math.sin(step) * stride, 0.12 + max(0, math.cos(step)) * lift + jump * 0.13)
        knee = joint_between(hip, ankle, 0.415, vec(0, 1, 0))
        shoulder = vec(sign * 0.28, 0, 1.36) + body
        hand = (vec(0.1, 0.12, 1.20) if side == 'R' else vec(0.035, 0.46 - reload * 0.25, 1.30 - reload * 0.17)) + body
        elbow = joint_between(shoulder, hand, 0.31, vec(sign, -0.2, -0.1))
        p.update({f'Hip.{side}': hip, f'Knee.{side}': knee, f'Ankle.{side}': ankle,
                  f'Toe.{side}': ankle + vec(0, 0.23, -0.035), f'Shoulder.{side}': shoulder,
                  f'Elbow.{side}': elbow, f'Hand.{side}': hand, f'Finger.{side}': hand + vec(0, 0.09, 0)})
    p['Weapon'] = vec(0.1, 0.235, 1.35) + body
    p['Barrel'] = p['Weapon'] + vec(0, 0.3, 0)
    if downed:
        # Four-point support: knees and palms, with a low forward-leaning torso.
        p.update({'Hips': vec(0, -0.08, 0.43 + breath),
                  'Spine': vec(0, 0.18, 0.72 + breath),
                  'Neck': vec(0, 0.25, 0.82 + breath),
                  'Head': vec(0, 0.34, 1.05 + breath)})
        for side, sign in [('L', -1), ('R', 1)]:
            step = math.sin(phase + (math.pi if sign == 1 else 0)) * stride
            hip = p['Hips'] + vec(sign * 0.14, 0, 0)
            knee = vec(sign * 0.18, 0.14 + step, 0.14)
            ankle = vec(sign * 0.18, -0.24 + step, 0.10)
            shoulder = p['Spine'] + vec(sign * 0.28, 0, 0)
            hand = vec(sign * 0.27, 0.43 - step, 0.15)
            elbow = joint_between(shoulder, hand, 0.31, vec(sign, -0.2, 0))
            p.update({f'Hip.{side}': hip, f'Knee.{side}': knee, f'Ankle.{side}': ankle,
                      f'Toe.{side}': ankle + vec(0, -0.23, -0.025),
                      f'Shoulder.{side}': shoulder, f'Elbow.{side}': elbow,
                      f'Hand.{side}': hand, f'Finger.{side}': hand + vec(0, 0.09, 0)})
        p['Weapon'] = p['Spine']
        p['Barrel'] = p['Weapon'] + vec(0, 0.3, 0)
    if seated:
        # Seat origin is at ground level. The pelvis rests on the buggy cushion;
        # forward-bent legs fit under the dashboard, hands meet the steering rim.
        p.update({'Hips': vec(0, 0, 0.99),
                  'Spine': vec(0, 0.08 + slump * 0.13, 1.34 + breath),
                  'Neck': vec(0, 0.10 + slump * 0.20, 1.43 + breath),
                  'Head': vec(0, 0.17 + slump * 0.24, 1.68 - slump * 0.12 + breath)})
        for side, sign in [('L', -1), ('R', 1)]:
            hip = p['Hips'] + vec(sign * 0.14, 0, 0)
            knee = vec(sign * 0.16, 0.38, 0.81)
            ankle = vec(sign * 0.16, 0.47, 0.41)
            shoulder = p['Spine'] + vec(sign * 0.28, 0, 0)
            hand = vec(sign * 0.15, 0.28, 1.19) if seated == 1 and not slump else vec(sign * 0.14, 0.34, 0.94)
            elbow = joint_between(shoulder, hand, 0.31, vec(sign * 0.35, -0.2, -1.0))
            p.update({f'Hip.{side}': hip, f'Knee.{side}': knee, f'Ankle.{side}': ankle,
                      f'Toe.{side}': ankle + vec(0, 0.23, -0.035),
                      f'Shoulder.{side}': shoulder, f'Elbow.{side}': elbow,
                      f'Hand.{side}': hand, f'Finger.{side}': hand + vec(0, 0.09, 0)})
        p['Weapon'] = p['Spine']
        p['Barrel'] = p['Weapon'] + vec(0, 0.3, 0)
    if death:
        pivot = vec(0, 0, 0.2)
        rotation = Matrix.Rotation(math.pi * 0.5 * death, 3, 'Y' if downed else 'X')
        for key in p:
            p[key] = pivot + rotation @ (p[key] - pivot)
            if downed:
                p[key].z += 0.15 * death
    return p


rest = joints()
# Parent-first ordering is also used when baking absolute joint targets to local keys.
bones = [('Root', 'Root', 'Hips', None), ('Hips', 'Hips', 'Spine', 'Root'),
         ('Spine', 'Spine', 'Neck', 'Hips'), ('Head', 'Neck', 'Head', 'Spine')]
for side in ('L', 'R'):
    bones += [(f'Thigh.{side}', f'Hip.{side}', f'Knee.{side}', 'Hips'),
              (f'Shin.{side}', f'Knee.{side}', f'Ankle.{side}', f'Thigh.{side}'),
              (f'Foot.{side}', f'Ankle.{side}', f'Toe.{side}', f'Shin.{side}'),
              (f'UpperArm.{side}', f'Shoulder.{side}', f'Elbow.{side}', 'Spine'),
              (f'Forearm.{side}', f'Elbow.{side}', f'Hand.{side}', f'UpperArm.{side}'),
              (f'Hand.{side}', f'Hand.{side}', f'Finger.{side}', f'Forearm.{side}')]
bones += [('Weapon', 'Weapon', 'Barrel', 'Spine')]
armature = bpy.data.armatures.new('OperatorSkeleton')
rig = bpy.data.objects.new('OperatorRig', armature)
bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name, start, end, parent in bones:
    bone = armature.edit_bones.new(name)
    bone.head = rest[start]
    bone.tail = rest[end]
    if parent:
        bone.parent = armature.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')


def skin(obj, bone):
    # Bake bevels before assigning every new edge vertex to its rigid armor segment.
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    modifier = obj.modifiers.new('Operator skin', 'ARMATURE')
    modifier.object = rig
    obj.parent = rig
    return obj


def panel(name, center, dimensions, mat, bone, bevel=0.02):
    return skin(box(name, center, dimensions, mat, bevel), bone)


def organic(name, center, dimensions, mat, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=center)
    obj = bpy.context.object; obj.name = name
    obj.scale = Vector(dimensions) * 0.5
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons: polygon.use_smooth = True
    obj.data.materials.append(mat)
    return skin(obj, bone)


def limb(name, start, end, width, depth, mat, bone):
    direction = end - start
    vertices, faces = [], []
    rings, segments = 17, 24
    for ring in range(rings):
        t = ring/(rings-1)
        taper = 0.76 + 0.24*math.sin(math.pi*t)
        for segment in range(segments):
            angle = segment*math.tau/segments
            fold = 1 + 0.055*math.sin(t*31 + math.sin(angle*3))*math.sin(math.pi*t)
            vertices.append((math.cos(angle)*width*0.5*taper*fold,
                             math.sin(angle)*depth*0.5*taper*fold, (t-0.5)*direction.length))
    for ring in range(rings-1):
        for segment in range(segments):
            n=(segment+1)%segments
            faces.append((ring*segments+segment,ring*segments+n,(ring+1)*segments+n,(ring+1)*segments+segment))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='Uniform UV')
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for loop in polygon.loop_indices:
            index=mesh.loops[loop].vertex_index;u=(index%segments)/segments
            if polygon.index%segments==segments-1 and u==0:u=1
            uv.data[loop].uv=(u,index//segments/(rings-1)*1.5)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.location=(start+end)/2;obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=vec(0,0,1).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    return skin(obj,bone)


# Fabric folds and rounded anatomy replace the original rigid block silhouette.
fabric=cloth.node_tree.nodes.new('ShaderNodeTexImage')
fabric.image=bpy.data.images.load(str(ROOT/'client/assets/realism/uniform.png'))
cloth.node_tree.links.new(fabric.outputs['Color'],cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
webbing=material('Olive nylon webbing',(0.075,0.088,0.044))
rubber=material('Boot rubber and balaclava',(0.014,0.018,0.012))
organic('Uniform torso',(0,0,1.18),(0.49,0.29,0.49),cloth,'Hips')
panel('Front carrier',(0,0.145,1.21),(0.37,0.07,0.34),webbing,'Hips',0.035)
panel('Rear carrier',(0,-0.145,1.21),(0.38,0.06,0.35),webbing,'Hips',0.035)
organic('Trouser hips',(0,0,0.93),(0.39,0.27,0.24),cloth,'Hips')
organic('Covered head',(0,0.01,1.58),(0.27,0.28,0.35),rubber,'Head')
organic('Helmet shell',(0,-0.012,1.70),(0.35,0.36,0.21),webbing,'Head')
for sign in [-1,1]:
    organic('Goggle rim',(sign*0.065,0.145,1.642),(0.143,0.055,0.082),rubber,'Head')
    organic('Goggle lens',(sign*0.065,0.168,1.644),(0.116,0.020,0.055),visor,'Head')
    panel('Carrier shoulder strap',(sign*0.15,0.03,1.395),(0.065,0.30,0.045),webbing,'Hips',0.012)
    panel('Helmet rail',(sign*0.172,-0.015,1.69),(0.025,0.17,0.035),rubber,'Head',0.008)
for row in range(4):
    panel('Carrier stitching',(0,0.187,1.12+row*0.061),(0.35,0.009,0.014),cloth,'Hips',0.003)
for x in [-0.11,0,0.11]:
    panel('Magazine pouch',(x,0.207,1.12),(0.094,0.075,0.16),webbing,'Hips',0.012)
    panel('Pouch flap',(x,0.248,1.185),(0.09,0.008,0.037),cloth,'Hips',0.004)
panel('Field pack',(0,-0.24,1.20),(0.32,0.19,0.37),webbing,'Hips',0.05)
for side, sign in [('L',-1),('R',1)]:
    limb('Trouser thigh '+side,rest['Hip.'+side],rest['Knee.'+side],0.22,0.23,cloth,'Thigh.'+side)
    limb('Trouser shin '+side,rest['Knee.'+side],rest['Ankle.'+side],0.17,0.18,cloth,'Shin.'+side)
    organic('Boot '+side,(sign*0.14,0.057,0.09),(0.17,0.32,0.18),rubber,'Foot.'+side)
    panel('Boot sole '+side,(sign*0.14,0.065,0.025),(0.17,0.33,0.035),rubber,'Foot.'+side,0.012)
    limb('Sleeve '+side,rest['Shoulder.'+side],rest['Elbow.'+side],0.18,0.18,cloth,'UpperArm.'+side)
    limb('Forearm '+side,rest['Elbow.'+side],rest['Hand.'+side],0.13,0.14,cloth,'Forearm.'+side)
    organic('Glove '+side,rest['Hand.'+side],(0.105,0.13,0.085),rubber,'Hand.'+side)
    for joint,bone,radius in [('Knee.','Shin.',0.085),('Elbow.','Forearm.',0.060),('Shoulder.','UpperArm.',0.09)]:
        organic(joint+side,rest[joint+side],(radius*2,radius*2,radius*2),cloth,bone+side)
    panel('Knee pad '+side,rest['Knee.'+side]+vec(0,0.083,0),(0.13,0.042,0.13),webbing,'Shin.'+side,0.025)
    panel('Cargo pocket '+side,rest['Hip.'+side]+vec(sign*0.105,0,-0.13),(0.045,0.14,0.16),cloth,'Thigh.'+side,0.014)
# Weapon bone remains animated; Godot attaches the currently equipped model.

# One skinned mesh with material surfaces avoids dozens of mesh submissions per actor.
bpy.ops.object.select_all(action='DESELECT')
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
bpy.context.object.name = 'OperatorSkin'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
rig.animation_data_create()
clips = [('Idle', 60, {}), ('Walk', 30, {'stride': 0.22, 'lift': 0.10}),
         ('Run', 20, {'stride': 0.31, 'lift': 0.15}), ('CrouchIdle', 60, {'crouch': 1}),
         ('CrouchWalk', 36, {'crouch': 1, 'stride': 0.10, 'lift': 0.045}),
         ('CrouchReload', 60, {'crouch': 1, 'reload': 1}),
         ('DownedIdle', 60, {'downed': 1}),
         ('DownedCrawl', 48, {'downed': 1, 'stride': 0.07}),
         ('DownedDeath', 24, {'downed': 1, 'death': 1}),
         ('SeatedDriver', 60, {'seated': 1}),
         ('SeatedPassenger', 60, {'seated': 2}),
         ('SeatedDowned', 60, {'seated': 2, 'slump': 1}),
         ('Jump', 24, {'jump': 1}), ('Reload', 60, {'reload': 1}), ('Death', 32, {'death': 1})]
bpy.context.scene.render.fps = 30
for clip, end_frame, options in clips:
    action = bpy.data.actions.new(clip)
    rig.animation_data.action = action
    for frame in range(0, end_frame + 1, 2):
        bpy.context.scene.frame_set(frame)
        progress = frame / end_frame
        parameters = dict(options)
        parameters['phase'] = progress * math.tau
        parameters['breath'] = math.sin(progress * math.tau) * (0.004 if 'crouch' in options else 0.006)
        if 'reload' in options:
            parameters['reload'] = math.sin(progress * math.pi) ** 2
        if 'death' in options:
            parameters['death'] = min(1, progress * 1.35)
            parameters['breath'] = 0
        points = joints(**parameters)
        for name, start, end, _ in bones:
            pose = rig.pose.bones[name]
            old_direction = (rest[end] - rest[start]).normalized()
            new_direction = (points[end] - points[start]).normalized()
            delta = old_direction.rotation_difference(new_direction)
            orientation = delta @ pose.bone.matrix_local.to_quaternion()
            pose.matrix = Matrix.LocRotScale(points[start], orientation, Vector((1, 1, 1)))
            bpy.context.view_layer.update()
            pose.rotation_mode = 'QUATERNION'
            pose.keyframe_insert('location', frame=frame, group=name)
            pose.keyframe_insert('rotation_quaternion', frame=frame, group=name)
            pose.keyframe_insert('scale', frame=frame, group=name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = 'LINEAR'
    track = rig.animation_data.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, 0, action)
    track.mute = True
    rig.animation_data.action = None
# Export actions, not combined NLA evaluation, to keep each clip independently addressable.
rig.animation_data.action = bpy.data.actions['Idle']
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'operator.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'operator.glb'), export_format='GLB', use_selection=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True)
print('RIG_BUILT bones=%d clips=%s' % (len(bones), ','.join(name for name, _, _ in clips)))
