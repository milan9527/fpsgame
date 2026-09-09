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


def joints(crouch=0.0, phase=0.0, stride=0.0, lift=0.0, reload=0.0, jump=0.0, breath=0.0, death=0.0):
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
    if death:
        pivot = vec(0, 0, 0.2)
        rotation = Matrix.Rotation(math.pi * 0.5 * death, 3, 'X')
        for key in p:
            p[key] = pivot + rotation @ (p[key] - pivot)
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


def limb(name, start, end, width, depth, mat, bone):
    direction = end - start
    obj = box(name, (start + end) / 2, (width, depth, direction.length * 0.88), mat, 0.025)
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = vec(0, 0, 1).rotation_difference(direction.normalized())
    return skin(obj, bone)


panel('Chest plates', (0, 0, 1.19), (0.50, 0.29, 0.43), armor, 'Hips', 0.045)
panel('Pelvis armor', (0, 0, 0.92), (0.37, 0.26, 0.18), cloth, 'Hips', 0.025)
panel('Helmet', (0, 0, 1.62), (0.37, 0.37, 0.32), armor, 'Head', 0.065)
panel('Visor', (0, 0.183, 1.62), (0.30, 0.022, 0.105), visor, 'Head', 0.008)
panel('Pack', (0, -0.19, 1.19), (0.35, 0.17, 0.33), cloth, 'Hips', 0.025)
for side, sign in [('L', -1), ('R', 1)]:
    limb('Thigh armor ' + side, rest['Hip.' + side], rest['Knee.' + side], 0.20, 0.22, cloth, 'Thigh.' + side)
    limb('Shin armor ' + side, rest['Knee.' + side], rest['Ankle.' + side], 0.18, 0.20, cloth, 'Shin.' + side)
    panel('Boot ' + side, (sign * 0.14, 0.055, 0.09), (0.22, 0.35, 0.18), steel, 'Foot.' + side)
    limb('Sleeve ' + side, rest['Shoulder.' + side], rest['Elbow.' + side], 0.17, 0.19, cloth, 'UpperArm.' + side)
    limb('Forearm ' + side, rest['Elbow.' + side], rest['Hand.' + side], 0.13, 0.15, cloth, 'Forearm.' + side)
    panel('Glove ' + side, rest['Hand.' + side], (0.12, 0.13, 0.11), steel, 'Hand.' + side)
    for joint, bone, radius in [('Knee.', 'Shin.', 0.095), ('Elbow.', 'Forearm.', 0.065), ('Shoulder.', 'UpperArm.', 0.095)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=radius, location=rest[joint + side])
        obj = bpy.context.object
        obj.name = joint + side + ' flexible joint'
        obj.data.materials.append(armor)
        skin(obj, bone + side)
    panel('Pouch ' + side, (sign * 0.12, 0.17, 1.11), (0.12, 0.10, 0.17), cloth, 'Hips')
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
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'operator.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'operator.glb'), export_format='GLB', use_selection=True,
                          export_animations=True, export_animation_mode='ACTIONS', export_skins=True)
print('RIG_BUILT bones=%d clips=%s' % (len(bones), ','.join(name for name, _, _ in clips)))
