"""Original tactical operator skin and keyed locomotion clips, authored in Blender.
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


def reload_lean(progress):
    reach = min(1.0, max(0.0, progress / 0.40))
    recover = min(1.0, max(0.0, (progress - 0.55) / 0.45))
    weight = reach * reach * (3 - 2 * reach)
    weight *= 1 - recover * recover * (3 - 2 * recover)
    lean = Matrix.Rotation(math.radians(-12) * weight, 3, 'X')
    return Matrix.Rotation(math.radians(-6) * weight, 3, 'Y') @ lean, weight


def joints(crouch=0.0, phase=0.0, stride=0.0, lift=0.0, reload=-1.0, jump=0.0, breath=0.0, death=0.0, downed=0.0, seated=0, slump=0):
    # Sit back over a wider support polygon instead of folding the pelvis
    # directly onto the heels. Keep the head within the crouched gameplay height.
    body = vec(0, -0.30 * crouch, -0.60 * crouch + breath)
    p = {'Root': vec(0, 0, 0), 'Hips': vec(0, 0, 0.94) + body,
         'Spine': vec(0, 0, 1.36) + body, 'Neck': vec(0, 0, 1.48) + body,
         'Head': vec(0, 0, 1.76) + body}
    for side, sign in [('L', -1), ('R', 1)]:
        step = phase + (math.pi if sign == 1 else 0)
        hip = vec(sign * 0.14, 0, 0.94) + body
        ankle = vec(sign * (0.14 + 0.05 * crouch), math.sin(step) * stride, 0.12 + max(0, math.cos(step)) * lift + jump * 0.13)
        # A soft ready stance leaves visible knee flexion in the side silhouette.
        # Use the same segment length for bind pose and every action clip.
        knee = joint_between(hip, ankle, 0.430, vec(sign * 0.20 * crouch, 1, 0))
        shoulder = vec(sign * 0.28, 0, 1.36) + body
        hand = vec(0.1, 0.12, 1.20) if side == 'R' else vec(0.035, 0.46, 1.30)
        if side == 'L' and reload >= 0:
            # Release the fore-end, reach the belt, present the fresh magazine,
            # seat it under the receiver, then recover the supporting grip.
            # Keep the firing grip fixed relative to the weapon; the upper-body
            # follow-through below carries both through the manipulation.
            path = [(0.0, vec(0.035, 0.46, 1.30)),
                    (0.18, vec(0.035, 0.21, 1.13)),
                    (0.40, vec(-0.27, 0.10, 0.90)),
                    (0.55, vec(-0.27, 0.10, 0.90)),
                    (0.73, vec(0.035, 0.21, 1.13)),
                    (0.82, vec(0.035, 0.21, 1.23)),
                    (1.0, vec(0.035, 0.46, 1.30))]
            for (a, start), (b, end) in zip(path, path[1:]):
                if a <= reload <= b:
                    t = (reload - a) / (b - a)
                    hand = start.lerp(end, t * t * (3 - 2 * t))
                    break
        hand += body
        elbow = joint_between(shoulder, hand, 0.31, vec(sign, -0.2, -0.1))
        p.update({f'Hip.{side}': hip, f'Knee.{side}': knee, f'Ankle.{side}': ankle,
                  f'Toe.{side}': ankle + vec(0, 0.23, -0.035), f'Shoulder.{side}': shoulder,
                  f'Elbow.{side}': elbow, f'Hand.{side}': hand, f'Finger.{side}': hand + vec(0, 0.09, 0)})
    p['Weapon'] = vec(0.1, 0.235, 1.35) + body
    p['Barrel'] = p['Weapon'] + vec(0, 0.3, 0)
    if reload >= 0:
        # Shift the chest towards the working hand during the belt reach, then
        # recover the ready stance after seating the magazine. Transform the
        # whole shoulder/arm/weapon chain together to preserve grip contact and
        # limb lengths, while leaving the planted feet and pelvis in place.
        lean, weight = reload_lean(reload)
        pivot = p['Hips']
        upper = ['Spine', 'Neck', 'Head', 'Weapon', 'Barrel']
        upper += [f'{joint}.{side}' for side in ('L', 'R')
                  for joint in ('Shoulder', 'Elbow', 'Hand', 'Finger')]
        for key in upper:
            p[key] = pivot + lean @ (p[key] - pivot)
        # The gaze anticipates magazine seating instead of keeping the helmet
        # locked to the chest. This also returns exactly to the bind direction.
        gaze = Matrix.Rotation(math.radians(-9) * weight, 3, 'X')
        p['Head'] = p['Neck'] + gaze @ (p['Head'] - p['Neck'])
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
    obj = skin(box(name, center, dimensions, mat, bevel), bone)
    if mat == cloth:
        uv = obj.data.uv_layers.active
        for polygon in obj.data.polygons:
            axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
            axes = [i for i in range(3) if i != axis]
            for loop in polygon.loop_indices:
                point = obj.data.vertices[obj.data.loops[loop].vertex_index].co
                uv.data[loop].uv = (point[axes[0]] / 0.6, point[axes[1]] / 0.6)
    return obj


def sewn_pad(name, center, width, height, depth, mat, bone, exponent=.68):
    """Rounded sewn outline with a domed face; no flat cuboid front."""
    vertices, faces = [], []
    count = 32
    # Outer edge, raised seam, and progressively softer convex center.
    for scale, bulge in [(1,0),(.96,.22),(.82,.69),(.52,.94),(.12,1)]:
        for i in range(count):
            a = math.tau*i/count
            x = math.copysign(abs(math.cos(a))**exponent, math.cos(a))
            z = math.copysign(abs(math.sin(a))**exponent, math.sin(a))
            taper = 1-.10*max(0,-z)
            vertices.append(Vector(center)+vec(x*width*.5*scale*taper,
                depth*bulge, z*height*.5*scale))
    faces.append(tuple(reversed(range(count))))
    for r in range(4):
        for i in range(count):
            j=(i+1)%count
            faces.append((r*count+i,r*count+j,(r+1)*count+j,(r+1)*count+i))
    faces.append(tuple(range(4*count,5*count)))
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces); mesh.update()
    import bmesh
    topology = bmesh.new()
    topology.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(topology, faces=list(topology.faces))
    topology.to_mesh(mesh)
    topology.free()
    obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    uv=mesh.uv_layers.new(name='Sewn fabric')
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for loop in polygon.loop_indices:
            point=mesh.vertices[mesh.loops[loop].vertex_index].co-Vector(center)
            uv.data[loop].uv=(point.x/.6,point.z/.6)
    return skin(obj,bone)


def cargo_pocket(side, sign):
    """Soft gusset and overlapping flap following the outer thigh."""
    center = rest['Hip.'+side]+vec(sign*.089, -.004, -.145)
    def patch(label, offset, width, height, depth, exponent):
        obj = sewn_pad(label+' '+side, (0,0,0), width, height, depth,
                       cloth, 'Thigh.'+side, exponent)
        # The pad's +Y face becomes the outward thigh face. Preserve winding.
        for vertex in obj.data.vertices:
            x, y, z = vertex.co
            vertex.co = center+offset+vec(sign*y, -sign*x, z)
        obj.data.update()
    patch('Cargo bellows', vec(0,0,0), .148, .198, .035, .60)
    patch('Cargo folded flap', vec(sign*.023,0,.067), .150, .066, .014, .48)
    patch('Cargo center pleat', vec(sign*.032,0,-.031), .024, .098, .004, .72)


def carrier_plate(name, facing):
    """Clipped shoulder corners and a bowed plate pocket following the ribs."""
    outline = [(-0.17, 1.045), (0.17, 1.045), (0.185, 1.09),
               (0.185, 1.285), (0.112, 1.385), (-0.112, 1.385),
               (-0.185, 1.285), (-0.185, 1.09)]
    vertices = []
    # Concentric face rings preserve the chest curvature across the broad face.
    for depth, scale in [(0, 1), (0.032, 1), (0.041, 0.78), (0.046, 0.38)]:
        for x, z in outline:
            x *= scale
            z = 1.21 + (z - 1.21) * scale
            y = facing * (0.139 + depth - 0.045 * (x / 0.185)**2)
            vertices.append((x, y, z))
    faces = [tuple(reversed(range(8)))]
    for ring in range(3):
        for i in range(8):
            j = (i + 1) % 8
            faces.append((ring*8+i, ring*8+j, (ring+1)*8+j, (ring+1)*8+i))
    faces.append(tuple(range(24, 32)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(webbing)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bevel = obj.modifiers.new('Bound fabric pocket edge', 'BEVEL')
    bevel.width = 0.006
    bevel.segments = 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return skin(obj, 'Spine')


def field_pack():
    """Tapered sewn daypack, with curved piping and functional strap hardware."""
    # Rounded bottom and crown, with fabric gathered beneath the two straps.
    # Dense vertical rings keep the side silhouette curved at gameplay distance.
    sections = [(1.015, .040, .022), (1.026, .083, .045),
                (1.052, .117, .073), (1.087, .139, .095),
                (1.12, .128, .084), (1.16, .148, .108),
                (1.205, .146, .111), (1.25, .137, .100),
                (1.285, .119, .079), (1.32, .125, .085),
                (1.351, .105, .070), (1.375, .070, .042),
                (1.384, .026, .018)]
    vertices, faces = [], []
    count = 32
    for z, width, depth in sections:
        for i in range(count):
            angle = 2 * math.pi * i / count
            c, s = math.cos(angle), math.sin(angle)
            # Broad shallow folds follow the compressed gussets, not surface noise.
            fold = .004 * math.sin(angle * 6 + z * 16) * abs(c)**2
            vertices.append((width * math.copysign(abs(c)**.88, c),
                             -.235 + depth * s + fold, z))
    faces.append(tuple(reversed(range(count))))
    for ring in range(len(sections)-1):
        for i in range(count):
            j = (i+1) % count
            faces.append((ring*count+i, ring*count+j,
                          (ring+1)*count+j, (ring+1)*count+i))
    faces.append(tuple(range((len(sections)-1)*count, len(sections)*count)))
    mesh = bpy.data.meshes.new('Sewn pack shell')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Sewn pack shell', mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(webbing)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    skin(obj, 'Spine')

    def piping(name, points, radius=.0025):
        curve = bpy.data.curves.new(name, 'CURVE')
        curve.dimensions = '3D'
        curve.bevel_depth = radius
        curve.bevel_resolution = 2
        spline = curve.splines.new('BEZIER')
        spline.bezier_points.add(len(points)-1)
        for point, position in zip(spline.bezier_points, points):
            point.co = position
            point.handle_left_type = point.handle_right_type = 'AUTO'
        obj = bpy.data.objects.new(name, curve)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(rubber)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target='MESH')
        skin(bpy.context.object, 'Spine')

    piping('Pack perimeter zipper',
           [(-.079,-.306,1.075),(-.086,-.319,1.24),(-.069,-.298,1.335),
            (0,-.288,1.365),(.069,-.298,1.335),(.086,-.319,1.24),(.079,-.306,1.075)])
    sewn_pad('Pack outer pocket',(0,-.303,1.183),.212,.192,-.061,
             webbing,'Spine',.82)
    piping('Outer pocket zipper',[(-.088,-.337,1.22),(-.05,-.356,1.25),
                                 (0,-.361,1.262),(.05,-.356,1.25),
                                 (.088,-.337,1.22)])
    piping('Pack carry handle',[(-.042,-.226,1.37),(-.031,-.228,1.408),
                               (.031,-.228,1.408),(.042,-.226,1.37)],.009)
    for sign in (-1, 1):
        # Flat webbing follows each side from the rear seam to the back panel.
        for z, width, depth in [(1.12,.128,.084),(1.285,.119,.079)]:
            for dz in (-.009,0,.009):
                piping('Pack wrapped compression webbing',
                       [(sign*.068,-.235-depth*.87,z+dz),
                        (sign*width*.91,-.235-depth*.45,z+dz),
                        (sign*width,-.235,z+dz),
                        (sign*width*.84,-.190,z+dz)],.0045)
            panel('Pack compression buckle',(sign*(width+.002),-.245,z),
                  (.014,.032,.029),rubber,'Spine',.004)
        piping('Pack gusset seam',[(sign*.064,-.269,1.03),
                (sign*.126,-.281,1.087),(sign*.119,-.272,1.12),
                (sign*.133,-.290,1.205),(sign*.108,-.270,1.285),
                (sign*.094,-.268,1.351),(sign*.028,-.248,1.382)])
        piping('Pack shoulder harness',[(sign*.112,-.206,1.347),
                (sign*.15,-.085,1.425),(sign*.15,.078,1.399)],.016)
    sewn_pad('Pack identification patch',(0,-.322,1.311),.066,.027,-.007,
             rubber,'Spine',.7)


def combat_boot(side, sign):
    """Low forefoot with a separate upright, padded ankle and laced tongue."""
    count = 24
    def loft(name, rings, mat, cap=True):
        vertices = [v for ring in rings for v in ring]
        faces = []
        if cap:
            faces.append(tuple(reversed(range(count))))
        for ring in range(len(rings)-1):
            for i in range(count):
                j = (i+1) % count
                faces.append((ring*count+i, ring*count+j,
                              (ring+1)*count+j, (ring+1)*count+i))
        if cap:
            faces.append(tuple(range((len(rings)-1)*count, len(rings)*count)))
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name+' '+side, mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat)
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        skin(obj, 'Foot.'+side)
        return obj

    # The vamp no longer slopes down from the top of the ankle like a wedge.
    sections = [(-.095,.035,.090), (-.075,.050,.115),
                (-.040,.054,.128), (0,.055,.134), (.035,.059,.127),
                (.070,.064,.113), (.105,.066,.101), (.140,.064,.096),
                (.165,.057,.090), (.185,.043,.080), (.195,.023,.066)]
    for sole in (False, True):
        rings = []
        for y, width, top in sections:
            contact = .007 if -.015 <= y <= .040 else .001
            if y >= .178:
                contact = .006+(y-.178)*.35
            bottom = contact if sole else .037
            top = .045 if sole else top
            ring = []
            for i in range(count):
                angle = 2*math.pi*i/count
                c, t = math.cos(angle), math.sin(angle)
                x = math.copysign(abs(c)**.65,c)*(width+(.003 if sole else 0))
                height = (1+math.copysign(abs(t)**.65,t))/2
                ring.append((sign*.14+x,y,bottom+(top-bottom)*height))
            rings.append(ring)
        loft('Boot outsole' if sole else 'Boot vamp',rings,rubber if sole else boot_leather)

    # Horizontal ankle rings produce an upright shaft with a padded rolled
    # collar; the inset return closes its rim without a solid cap over trousers.
    rings = []
    for z, rx, ry, cy in [(.065,.047,.067,-.025),(.115,.053,.067,-.019),
                          (.155,.050,.060,-.020),(.208,.054,.057,-.025),
                          (.239,.057,.058,-.025),(.248,.055,.056,-.025),
                          (.248,.046,.047,-.025),(.229,.044,.046,-.025)]:
        rings.append([(sign*.14+rx*math.cos(2*math.pi*i/count),
                       cy+ry*math.sin(2*math.pi*i/count),z) for i in range(count)])
    loft('Boot ankle and padded collar',rings,boot_leather,cap=False)

    # Raised tongue bends from instep to shin, rather than floating laces on
    # the descending vamp. Flattened elliptical sections give soft sewn edges.
    rings = []
    tongue = [(.088,.114,.023),(.065,.139,.027),(.047,.166,.030),
              (.038,.200,.030),(.035,.231,.027)]
    for y,z,width in tongue:
        rings.append([(sign*.14+width*math.cos(2*math.pi*i/count),
                       y+.004*math.sin(2*math.pi*i/count),z) for i in range(count)])
    loft('Boot padded tongue',rings,webbing)
    for index,(y,z,width) in enumerate(tongue[1:]):
        lace = panel('Boot crossed lace '+side,(sign*.14,y+.006,z),
                     (width*1.75,.004,.004),webbing,'Foot.'+side,.0015)
        lace.rotation_euler.y = (-1 if index%2 else 1)*.14
    # Rounded leather reinforcement is distinct from the rubber outsole.
    organic('Boot toe reinforcement '+side,(sign*.14,.139,.073),
            (.127,.099,.047),boot_leather,'Foot.'+side)


def organic(name, center, dimensions, mat, bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, radius=1, location=center)
    obj = bpy.context.object; obj.name = name
    obj.scale = Vector(dimensions) * 0.5
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons: polygon.use_smooth = True
    obj.data.materials.append(mat)
    if mat == cloth:
        circumference = math.pi * (dimensions[0] + dimensions[1]) / 2
        for uv in obj.data.uv_layers.active.data:
            uv.uv.x *= circumference / 0.6
            uv.uv.y *= dimensions[2] / 0.6
    return skin(obj, bone)


def tactical_glove(side, sign):
    """A cupped palm and separate curled digits in the hand bone's bind frame."""
    wrist = rest['Hand.'+side]
    bone = 'Hand.'+side
    organic('Glove palm '+side, wrist+vec(0,0.033,0),
            (0.078,0.095,0.042),webbing,bone)
    panel('Glove wrist closure '+side,wrist+vec(0,-0.006,0),
          (0.077,0.026,0.048),rubber,bone,0.010)
    # Each digit curves around a grip. Cross sections turn with the centerline
    # so the fingertips are rounded instead of overlapping capsule joints.
    def digit(name, points, radius):
        vertices, faces = [], []
        for i, point in enumerate(points):
            tangent = (points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            across = vec(1,0,0)
            across = (across-tangent*across.dot(tangent)).normalized()
            up = tangent.cross(across).normalized()
            taper = [0.86,1.0,0.93,0.78,0.48,0.08][i]
            for j in range(10):
                angle = math.tau*j/10
                vertices.append(wrist+point+radius*taper*(across*math.cos(angle)+up*math.sin(angle)))
        for i in range(len(points)-1):
            for j in range(10):
                k = (j+1)%10
                faces.append((i*10+j,i*10+k,(i+1)*10+k,(i+1)*10+j))
        faces.extend([tuple(reversed(range(10))),
                      tuple((len(points)-1)*10+j for j in range(10))])
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        obj = bpy.data.objects.new(name,mesh)
        bpy.context.collection.objects.link(obj)
        obj.data.materials.append(webbing)
        for face in mesh.polygons:
            face.use_smooth = True
        skin(obj,bone)
    for i, length in enumerate([0.052,0.060,0.056,0.043]):
        x = sign*(-0.029+i*0.019)
        digit('Glove finger %s %d'%(side,i),[
            vec(x,0.057,0.002),vec(x,0.071,0.006),
            vec(x,0.070+length*0.40,-0.002),
            vec(x,0.075+length*0.43,-0.020),
            vec(x,0.064+length*0.32,-0.034),
            vec(x,0.054+length*0.24,-0.035)],0.009)
        organic('Knuckle reinforcement %s %d'%(side,i),
                wrist+vec(x,0.064,0.018),(0.015,0.022,0.009),rubber,bone)
    digit('Glove thumb '+side,[
        vec(-sign*0.025,0.022,-0.005),vec(-sign*0.042,0.036,-0.009),
        vec(-sign*0.046,0.050,-0.017),vec(-sign*0.037,0.060,-0.026),
        vec(-sign*0.026,0.063,-0.029),vec(-sign*0.020,0.061,-0.028)],0.012)


def limb(name, start, end, width, depth, mat, bone):
    direction = end - start
    vertices, faces = [], []
    rings, segments = 33, 32
    # Garments narrow towards the wrist/ankle instead of swelling equally at
    # both ends. Broad compression folds survive the later 9 mm voxel union.
    profiles = {
        'Thigh': (0.94, 1.00, 0.95, 0.87, 0.82),
        # Calf volume sits below the knee; the bloused hem gathers onto the
        # boot cuff instead of ending as a broad rigid cylinder.
        'Shin': (0.88, 1.02, 0.91, 0.70, 0.62),
        'UpperArm': (0.96, 1.06, 0.96, 0.76, 0.75),
        'Forearm': (1.00, 1.06, 0.89, 0.68, 0.65),
    }
    profile = profiles.get(bone.split('.')[0], (0.85, 1, 1, 0.85, 0.75))
    for ring in range(rings):
        t = ring/(rings-1)
        section = min(int(t*4), 3)
        blend = t*4-section
        blend = blend*blend*(3-2*blend)
        taper = profile[section]*(1-blend) + profile[section+1]*blend
        for segment in range(segments):
            angle = segment*math.tau/segments
            joint_fold = math.exp(-((t-0.22)/0.20)**2) + math.exp(-((t-0.79)/0.19)**2)
            fold = 0.008*math.sin(t*31 + 1.4*math.sin(angle+0.6))*joint_fold
            fold += 0.003*math.sin(angle*3+t*9)*math.sin(math.pi*t)
            if bone.startswith(('UpperArm.', 'Forearm.')):
                # A sleeve hangs in long fabric planes. Compression belongs
                # beside the elbow and cuff, not in full rings around the arm.
                elbow_t = .88 if bone.startswith('UpperArm.') else .12
                compression = math.exp(-((t-elbow_t)/.15)**2)
                cuff = (math.exp(-((t-.88)/.10)**2)
                        if bone.startswith('Forearm.') else 0.0)
                fold = .004*math.cos(angle*3+.7*t)*math.sin(math.pi*t)
                # Directional bunching on the inside of the flexed elbow.
                # Preserve the joint endpoints and avoid circular hose ribs.
                inside = math.exp((math.cos(angle-1.8)-1)*1.2)
                fold += .012*math.sin(t*22+2.1*math.sin(angle))*compression*inside
                fold += .007*math.sin(t*27+1.6*math.sin(angle))*cuff
            if bone.startswith(('Thigh.', 'Shin.')):
                # Long shallow fabric channels and localized diagonal creases,
                # rather than concentric inflated rings along the entire leg.
                fold = .0025*math.cos(angle*3+.8*t)*math.sin(math.pi*t)
                compression = (math.exp(-((t-.86)/.13)**2) if bone.startswith('Thigh.')
                               else math.exp(-((t-.17)/.14)**2)
                               + .55*math.exp(-((t-.88)/.12)**2))
                fold += .005*math.sin(t*24+2.2*math.sin(angle))*compression
            vertices.append((math.cos(angle)*(width*0.5*taper+fold),
                             math.sin(angle)*(depth*0.5*taper+fold), (t-0.5)*direction.length))
    for ring in range(rings-1):
        for segment in range(segments):
            n=(segment+1)%segments
            faces.append((ring*segments+segment,ring*segments+n,(ring+1)*segments+n,(ring+1)*segments+segment))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((rings-1)*segments+i for i in range(segments)))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    # Match the UV layer on spheres/boxes so joining does not move cloth UVs
    # into TEXCOORD_1 while the material still samples TEXCOORD_0.
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for loop in polygon.loop_indices:
            index=mesh.loops[loop].vertex_index;u=(index%segments)/segments
            if polygon.index%segments==segments-1 and u==0:u=1
            circumference = math.pi * (width + depth) / 2
            uv.data[loop].uv=(u*circumference/0.6,index//segments/(rings-1)*direction.length/0.6)
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.location=(start+end)/2;obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=vec(0,0,1).rotation_difference(direction.normalized())
    obj.data.materials.append(mat)
    skin(obj,bone)
    # Fabric near joints shares adjacent bones; armor and pouches stay rigid.
    parent = next(parent for name, _, _, parent in bones if name == bone)
    child = next((name for name, _, _, parent_name in bones if parent_name == bone), None)
    for adjacent, at_end in [(parent, False), (child, True)]:
        if adjacent is None:
            continue
        group = obj.vertex_groups.new(name=adjacent)
        for ring in range(rings):
            t = ring / (rings - 1)
            distance = 1 - t if at_end else t
            weight = max(0.0, 0.5 * (1 - distance / 0.16))
            if weight > 0:
                indices = list(range(ring * segments, (ring + 1) * segments))
                obj.vertex_groups[bone].add(indices, 1 - weight, 'REPLACE')
                group.add(indices, weight, 'REPLACE')
    return obj

def masked_face():
    """One fitted cloth surface over jaw, cheeks and brow, instead of stacked balls."""
    profiles = [
        (1.490, .051, -.045, .071),
        (1.508, .070, -.067, .093),
        (1.532, .083, -.084, .100),
        (1.560, .092, -.095, .104),
        (1.597, .096, -.104, .112),
        (1.633, .092, -.108, .105),
        (1.665, .091, -.105, .101),
        (1.702, .083, -.091, .082),
        (1.729, .051, -.054, .048),
    ]
    vertices, faces = [], []
    segments = 48
    # Sample the cloth closely enough that subdivision preserves the nose and
    # lip/chin transitions instead of averaging across an entire facial feature.
    dense_profiles = []
    for lower, upper in zip(profiles, profiles[1:]):
        steps = max(1, math.ceil((upper[0] - lower[0]) / .008))
        for step in range(steps):
            t = step / steps
            dense_profiles.append(tuple(a + (b - a) * t for a, b in zip(lower, upper)))
    dense_profiles.append(profiles[-1])
    profiles = dense_profiles
    for z, width, back, front in profiles:
        for j in range(segments):
            angle = math.tau * j / segments
            side, facing = math.cos(angle), math.sin(angle)
            # A mandibular angle below the cheek, then a short rounded chin.
            # Keep the skull/goggle attachment heights independent of the jaw.
            jaw = math.exp(-((z - 1.535) / .035) ** 2)
            x = width * math.copysign(abs(side) ** (.86 - .18 * jaw), side)
            y = front * facing if facing >= 0 else -back * facing
            # Covered lips and the shallow crease separating lip from chin.
            forward = max(0, facing)
            y += (.003 * math.exp(-((z - 1.557) / .011) ** 2)
                  - .0015 * math.exp(-((z - 1.541) / .007) ** 2)) * forward ** 8
            # Narrow bridge, rounded tip and broader cloth tension at the nostrils.
            y += .021 * math.exp(-((z - 1.609) / .025) ** 2) * forward ** 32
            y += .008 * math.exp(-((z - 1.592) / .010) ** 2) * forward ** 20
            # Cheek hollows continue diagonally from the sides of the nose.
            cheek_z = 1.580 - .30 * abs(x)
            y -= .003 * math.exp(-((z - cheek_z) / .016) ** 2) * math.exp(-((abs(x) - .048) / .022) ** 2) * forward ** 3
            vertices.append((x, y, z))
    for ring in range(len(profiles) - 1):
        for j in range(segments):
            a = ring * segments + j
            b = ring * segments + (j + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.extend([tuple(reversed(range(segments))),
                  tuple((len(profiles) - 1) * segments + j for j in range(segments))])
    mesh = bpy.data.meshes.new('Anatomical balaclava surface')
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new('Fitted covered jaw and face', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mask_cloth)
    # Place the cylindrical seam at the back, away from the nose and cheeks.
    uv = mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        indices = [mesh.loops[i].vertex_index for i in polygon.loop_indices]
        us = [((index % segments + segments // 4) % segments) / segments for index in indices]
        if max(us) - min(us) > .5:
            us = [u + 1 if u < .5 else u for u in us]
        for loop, index, u in zip(polygon.loop_indices, indices, us):
            uv.data[loop].uv = (u, (vertices[index][2] - 1.490) / .239)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    smooth = obj.modifiers.new('Cloth over rounded facial contours', 'SUBSURF')
    smooth.levels = 1
    smooth.render_levels = 1
    skin(obj, 'Head')


def goggle_retention_band():
    """Continuous elastic band around the temples and occiput."""
    vertices, faces = [], []
    steps = 64
    for index in range(steps + 1):
        phi = .85 - (math.pi + 1.70) * index / steps
        for height in (-.011, .011):
            vertices.append((.106 * math.cos(phi),
                             -.005 + .114 * math.sin(phi),
                             1.642 + height))
    for index in range(steps):
        a = index * 2
        faces.append((a, a+1, a+3, a+2))
    mesh = bpy.data.meshes.new('Curved elastic goggle retention')
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(rubber)
    obj = bpy.data.objects.new('Continuous goggle band', mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    solid = obj.modifiers.new('Elastic band thickness', 'SOLIDIFY')
    solid.thickness = .002
    skin(obj, 'Head')


def helmet_chin_strap(sign):
    """Flat webbing follows the cheek and underside of the jaw."""
    points = [
        (sign * .116, -.018, 1.644),
        (sign * .105, .006, 1.594),
        (sign * .089, .032, 1.548),
        (sign * .063, .060, 1.513),
        (sign * .032, .075, 1.500),
        (0, .078, 1.498),
    ]
    vertices, faces = [], []
    for index, point in enumerate(points):
        tangent = Vector(points[min(index + 1, len(points) - 1)]) - Vector(points[max(0, index - 1)])
        outward = Vector((sign * .65, .75, -.18)).normalized()
        across = tangent.normalized().cross(outward).normalized() * .006
        vertices.extend([tuple(Vector(point) - across), tuple(Vector(point) + across)])
    for index in range(len(points) - 1):
        a = index * 2
        faces.append((a, a + 1, a + 3, a + 2))
    mesh = bpy.data.meshes.new('Contoured chin webbing')
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(webbing)
    obj = bpy.data.objects.new('Helmet retention strap ' + str(sign), mesh)
    bpy.context.collection.objects.link(obj)
    solid = obj.modifiers.new('Webbing thickness', 'SOLIDIFY')
    solid.thickness = .002
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    skin(obj, 'Head')


def fitted_goggles():
    # Rounded molded frame with a tessellated lens following the facial curve.
    corners = [(-1, -.35), (-.75, -1), (.65, -1), (1, -.45),
               (1, .50), (.65, 1), (-.70, 1), (-1, .50)]
    outline = []
    for i, corner in enumerate(corners):
        previous, following = corners[i-1], corners[(i+1) % len(corners)]
        start = tuple(.18*p + .82*c for p, c in zip(previous, corner))
        end = tuple(.18*n + .82*c for n, c in zip(following, corner))
        for t in (0, .5, 1):
            outline.append(tuple((1-t)**2*a + 2*t*(1-t)*c + t*t*b
                                 for a, c, b in zip(start, corner, end)))
    count = len(outline)
    lens_material = material('Smoked polycarbonate goggle lens', (.025, .041, .045))
    shader = lens_material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .20
    shader.inputs['IOR'].default_value = 1.58
    for sign in (-1, 1):
        vertices, faces = [], []
        for scale, depth in ((1, 0), (.86, .002), (.80, .004), (.40, .004)):
            for u, v in outline:
                x = sign * .049 + u * .046 * scale
                z = 1.643 + v * .024 * scale
                y = .121 - .039 * (abs(x) / .10) ** 2 + depth
                vertices.append((x, y, z))
        for ring in range(3):
            for j in range(count):
                faces.append(((ring+1)*count+j, (ring+1)*count+(j+1)%count,
                              ring*count+(j+1)%count, ring*count+j))
        center = len(vertices)
        vertices.append((sign*.049, .125-.039*(.049/.10)**2, 1.643))
        for j in range(count):
            faces.append((3*count+(j+1)%count, 3*count+j, center))
        mesh = bpy.data.meshes.new('Wraparound goggle')
        mesh.from_pydata(vertices, [], faces)
        mesh.materials.append(rubber)
        mesh.materials.append(lens_material)
        for polygon in mesh.polygons:
            polygon.material_index = int(polygon.index >= 2*count)
            polygon.use_smooth = True
        obj = bpy.data.objects.new('Fitted goggle frame and lens', mesh)
        bpy.context.collection.objects.link(obj)
        solid = obj.modifiers.new('Goggle frame thickness', 'SOLIDIFY')
        solid.thickness = .003
        skin(obj, 'Head')
    panel('Goggle bridge', (0, .119, 1.648), (.018, .012, .014), rubber, 'Head', .003)


def helmet_surface(theta, phi):
    side, facing = math.cos(phi), math.sin(phi)
    edge_weight = math.sin(theta) ** 6
    rim_height = (.030 * abs(side) ** 6
                  + .018 * max(0, facing) ** 4
                  - .019 * max(0, -facing) ** 3)
    return Vector((.128 * math.sin(theta) * side,
                   -.012 + .145 * math.sin(theta) * facing
                   - .009 * max(0, facing) ** 5 * edge_weight,
                   1.650 + .136 * math.cos(theta) + rim_height * edge_weight))


def helmet_accessory_rail(sign):
    """Two narrow curved lips around a recessed equipment attachment channel."""
    for name, low, high, offset, material in (
            ('Rail channel', 1.40, 1.53, .003, rubber),
            ('Rail upper lip', 1.40, 1.435, .006, webbing),
            ('Rail lower lip', 1.495, 1.53, .006, webbing)):
        vertices, faces = [], []
        for index in range(17):
            phi = -.65 + 1.15 * index / 16
            # Taper the ends without introducing a square protruding block.
            taper = min(1.0, .45 + min(index, 16-index) * .28)
            middle = (low + high) / 2
            for theta in (middle + (low-middle)*taper,
                          middle + (high-middle)*taper):
                point = helmet_surface(theta, phi)
                point.x = sign * (point.x + offset * math.cos(phi))
                point.y += offset * math.sin(phi)
                vertices.append(tuple(point))
        for index in range(16):
            a = index * 2
            face = (a, a+1, a+3, a+2)
            faces.append(face if sign > 0 else tuple(reversed(face)))
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name + ' ' + str(sign), mesh)
        bpy.context.collection.objects.link(obj)
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        solid = obj.modifiers.new('Rail wall thickness', 'SOLIDIFY')
        solid.thickness = .002
        skin(obj, 'Head')


def helmet_shell():
    """Contoured high-cut shell with brow clearance and a lowered nape."""
    vertices, faces = [], []
    rings, segments = 12, 40
    for ring in range(rings + 1):
        theta = 0.025 + (math.pi / 2 - 0.025) * ring / rings
        for segment in range(segments):
            phi = segment * math.tau / segments
            vertices.append(tuple(helmet_surface(theta, phi)))
    for ring in range(rings):
        for segment in range(segments):
            n = (segment + 1) % segments
            faces.append((ring*segments+segment, (ring+1)*segments+segment,
                          (ring+1)*segments+n, ring*segments+n))
    faces.append(tuple(range(segments)))
    mesh = bpy.data.meshes.new('Protective helmet shell')
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new('Helmet shell', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(helmet_coating)
    # A top projection avoids a longitude seam across the brow. The shell
    # has no underside, so each surface point maps to a unique texel region.
    uv = mesh.uv_layers.new(name='Helmet coating')
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    solid = obj.modifiers.new('Shell thickness', 'SOLIDIFY')
    solid.thickness = 0.004
    edge = obj.modifiers.new('Rounded shell edge', 'BEVEL')
    edge.width = 0.0015
    edge.segments = 2
    skin(obj, 'Head')
    rim_vertices, rim_faces = [], []
    for theta in (math.pi / 2 - .027, math.pi / 2):
        for segment in range(segments):
            phi = segment * math.tau / segments
            point = helmet_surface(theta, phi)
            point += Vector((math.cos(phi), math.sin(phi), 0)) * .0012
            rim_vertices.append(tuple(point))
    for segment in range(segments):
        n = (segment + 1) % segments
        rim_faces.append((segment, segments+segment, segments+n, n))
    rim_mesh = bpy.data.meshes.new('Molded helmet perimeter')
    rim_mesh.from_pydata(rim_vertices, [], rim_faces)
    rim_mesh.materials.append(rubber)
    rim = bpy.data.objects.new('Protective rubber helmet edging', rim_mesh)
    bpy.context.collection.objects.link(rim)
    for polygon in rim_mesh.polygons:
        polygon.use_smooth = True
    thickness = rim.modifiers.new('Rubber edge thickness', 'SOLIDIFY')
    thickness.thickness = .002
    skin(rim, 'Head')
    return obj


def continuous_uniform(prefixes, name):
    """Fuse overlapping garment volumes; interpolate the original joint weights.

    Equipment stays separate so the carrier, pockets and protective pads retain
    their hard edges. Nine-millimetre voxels remove internal intersections without
    erasing the sleeve folds; UV islands are rescaled to the fabric's metre scale.
    """
    parts = [o for o in bpy.context.scene.objects
             if o.type == 'MESH' and o.name.startswith(prefixes)]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    source = bpy.context.object
    source.name = 'Uniform weight source'
    for mod in list(source.modifiers):
        source.modifiers.remove(mod)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj = source.copy()
    obj.data = source.data.copy()
    bpy.context.collection.objects.link(obj)
    source.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.name = name
    remesh = obj.modifiers.new('Join garment intersections', 'REMESH')
    remesh.mode = 'VOXEL'
    is_sleeve = any(part.startswith(('Sleeve', 'Forearm')) for part in prefixes)
    remesh.voxel_size = 0.0045 if is_sleeve else 0.009
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = obj.modifiers.new('Relax garment joins', 'SMOOTH')
    smooth.factor = 0.65
    smooth.iterations = 2 if is_sleeve else 3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    reduce = obj.modifiers.new('Garment surface budget', 'DECIMATE')
    reduce.ratio = 0.55
    bpy.ops.object.modifier_apply(modifier=reduce.name)
    obj.vertex_groups.clear()
    for group in source.vertex_groups:
        obj.vertex_groups.new(name=group.name)
    transfer = obj.modifiers.new('Interpolate garment skin', 'DATA_TRANSFER')
    transfer.object = source
    transfer.use_vert_data = True
    transfer.data_types_verts = {'VGROUP_WEIGHTS'}
    transfer.vert_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.modifier_apply(modifier=transfer.name)
    # glTF retains at most four influences; normalize those explicitly.
    for vertex in obj.data.vertices:
        weights = sorted([(g.group, g.weight) for g in vertex.groups],
                         key=lambda item: item[1], reverse=True)[:4]
        total = sum(w for _, w in weights)
        assert total > 0.001, 'Unweighted uniform vertex'
        for group in obj.vertex_groups:
            group.remove([vertex.index])
        for index, weight in weights:
            obj.vertex_groups[index].add([vertex.index], weight/total, 'REPLACE')
    bpy.data.objects.remove(source, do_unlink=True)
    while obj.data.uv_layers:
        obj.data.uv_layers.remove(obj.data.uv_layers[0])
    obj.data.uv_layers.new(name='UVMap')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(70), island_margin=0.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    uv = obj.data.uv_layers.active.data
    area = 0.0
    for polygon in obj.data.polygons:
        points = [uv[i].uv for i in polygon.loop_indices]
        area += abs(sum(points[i].cross(points[(i+1) % len(points)])
                        for i in range(len(points)))) * 0.5
        polygon.use_smooth = True
    scale = math.sqrt(sum(p.area for p in obj.data.polygons)/area)/0.6
    for loop in uv:
        loop.uv *= scale
    modifier = obj.modifiers.new('Operator skin', 'ARMATURE')
    modifier.object = rig
    print('CONTINUOUS_UNIFORM vertices=%d faces=%d' %
          (len(obj.data.vertices), len(obj.data.polygons)))


# Fabric folds and rounded anatomy replace the original rigid block silhouette.
fabric=cloth.node_tree.nodes.new('ShaderNodeTexImage')
fabric.image=bpy.data.images.load(str(ROOT/'client/assets/realism/uniform.png'))
cloth.node_tree.links.new(fabric.outputs['Color'],cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
webbing=material('Olive nylon webbing',(0.11,0.105,0.068))
helmet_coating=material('Matte olive helmet coating',(.095,.103,.066))
helmet_bsdf=helmet_coating.node_tree.nodes['Principled BSDF']
helmet_bsdf.inputs['Roughness'].default_value=.86
helmet_bsdf.inputs['Specular IOR Level'].default_value=.24
# Export actual pixels rather than Blender-only noise nodes. Low-frequency
# pigment variation remains readable under distant mipmaps; fine grain is
# deliberately low contrast to avoid shimmering during movement.
helmet_pixels=[]
for y in range(256):
    v=y/256
    for x in range(256):
        u=x/256
        pigment=(math.sin(math.tau*(2*u+v)) *
                 math.sin(math.tau*(u-3*v)) +
                 .4*math.sin(math.tau*(5*u+4*v)))
        grain=math.sin(x*12.9898+y*78.233)*43758.5453
        grain=grain-math.floor(grain)-.5
        shade=1+.085*pigment+.035*grain
        helmet_pixels.extend([1.055*(c*shade)**(1/2.4)-.055
                              for c in (.095,.103,.066)]+[1.0])
helmet_image=bpy.data.images.new('Helmet matte coating',width=256,height=256)
helmet_image.pixels.foreach_set(helmet_pixels)
helmet_image.pack()
helmet_texture=helmet_coating.node_tree.nodes.new('ShaderNodeTexImage')
helmet_texture.image=helmet_image
helmet_coating.node_tree.links.new(helmet_texture.outputs['Color'],
                                  helmet_bsdf.inputs['Base Color'])
rubber=material('Boot rubber',(0.014,0.018,0.012))
mask_cloth=material('Olive balaclava fabric',(0.105,0.115,0.075))
mask_cloth.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = 0.94
# Bake subdued yarn variation into a small exportable image: procedural Blender
# shader nodes do not survive glTF. Mipmaps filter the weave at gameplay distance.
mask_pixels = []
for y in range(256):
    v = y / 256
    for x in range(256):
        u = x / 256
        yarn = math.sin(math.tau * 64 * u) * math.sin(math.tau * 64 * v)
        mottling = math.sin(math.tau * (7*u + 3*v)) * math.sin(math.tau * (3*u - 5*v))
        shade = 1 + .045 * yarn + .055 * mottling
        # Image pixels are sRGB; preserve the original material's linear value.
        mask_pixels.extend([1.055 * (c * shade) ** (1/2.4) - .055
                            for c in (.105, .115, .075)] + [1.0])
mask_image = bpy.data.images.new('Balaclava woven olive', width=256, height=256)
mask_image.pixels.foreach_set(mask_pixels)
mask_image.pack()
mask_texture = mask_cloth.node_tree.nodes.new('ShaderNodeTexImage')
mask_texture.image = mask_image
mask_cloth.node_tree.links.new(mask_texture.outputs['Color'],
                              mask_cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
mask_cloth.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value = .22
boot_leather=material('Worn olive boot leather',(0.065,0.059,0.041))
# A tailored jacket keeps its width at the ribs, then slopes into the collar.
# Closed elliptical cross sections avoid the pinched ends of stacked spheres.
sections = [
    (0.965, .175, .124), (1.02, .190, .137), (1.12, .205, .142),
    (1.24, .225, .145), (1.33, .248, .137), (1.37, .248, .123),
    (1.40, .190, .105), (1.435, .087, .080), (1.47, .078, .075),
]
vertices, faces = [], []
segments = 48
for z, width, depth in sections:
    for i in range(segments):
        theta = math.tau * i / segments
        vertices.append((width * math.cos(theta), depth * math.sin(theta), z))
for row in range(len(sections) - 1):
    for i in range(segments):
        j = (i + 1) % segments
        faces.append((row*segments+i, row*segments+j,
                      (row+1)*segments+j, (row+1)*segments+i))
faces.extend([tuple(reversed(range(segments))),
              tuple((len(sections)-1)*segments+i for i in range(segments))])
mesh = bpy.data.meshes.new('Tailored jacket surface')
mesh.from_pydata(vertices, [], faces)
mesh.update()
jacket = bpy.data.objects.new('Uniform torso', mesh)
bpy.context.collection.objects.link(jacket)
jacket.data.materials.append(cloth)
skin(jacket, 'Hips')
# Let the chest follow aim pitch while the waist stays with the pelvis.
# This is assigned before garment fusion so the remesher interpolates the
# transition instead of leaving a rigid torso beneath animated shoulders.
chest_group = jacket.vertex_groups.new(name='Spine')
for vertex in jacket.data.vertices:
    height = (jacket.matrix_world @ vertex.co).z
    blend = max(0.0, min(1.0, (height - 1.04) / .29))
    blend = blend * blend * (3.0 - 2.0 * blend)
    jacket.vertex_groups['Hips'].add([vertex.index], 1.0 - blend, 'REPLACE')
    chest_group.add([vertex.index], blend, 'REPLACE')
carrier_plate('Front shaped plate pocket', 1)
carrier_plate('Rear shaped plate pocket', -1)
organic('Trouser hips',(0,0,0.93),(0.39,0.27,0.24),cloth,'Hips')
organic('Covered neck',(0,-.012,1.466),(.143,.146,.128),mask_cloth,'Head')
masked_face()
helmet_shell()
fitted_goggles()
goggle_retention_band()
for sign in [-1,1]:
    helmet_chin_strap(sign)
    panel('Carrier shoulder strap',(sign*0.15,0.03,1.395),(0.065,0.30,0.045),webbing,'Spine',0.012)
    helmet_accessory_rail(sign)
for row in range(4):
    for column in range(5 if row < 3 else 3):
        x = (column - (2 if row < 3 else 1)) * 0.057
        y = 0.191 - 0.045 * (x / 0.185)**2
        panel('Sewn webbing loop',(x,y,1.12+row*0.061),(0.051,0.006,0.021),webbing,'Spine',0.002)
for x in [-0.11,0,0.11]:
    sewn_pad('Magazine pouch',(x,0.185,1.12),.098,.17,.059,webbing,'Spine',.40)
    sewn_pad('Pouch folded flap',(x,.227,1.175),.086,.047,.021,cloth,'Spine',.48)
field_pack()
for side, sign in [('L',-1),('R',1)]:
    limb('Trouser thigh '+side,rest['Hip.'+side],rest['Knee.'+side],0.22,0.23,cloth,'Thigh.'+side)
    limb('Trouser shin '+side,rest['Knee.'+side],rest['Ankle.'+side],0.195,0.205,cloth,'Shin.'+side)
    combat_boot(side, sign)
    limb('Sleeve '+side,rest['Shoulder.'+side],rest['Elbow.'+side],0.145,0.155,cloth,'UpperArm.'+side)
    limb('Forearm '+side,rest['Elbow.'+side],rest['Hand.'+side],0.13,0.14,cloth,'Forearm.'+side)
    tactical_glove(side, sign)
    for joint,bone,radius in [('Knee.','Shin.',0.085),('Elbow.','Forearm.',0.060)]:
        organic(joint+side,rest[joint+side],(radius*2,radius*2,radius*2),cloth,bone+side)
    organic('Shoulder.'+side,rest['Shoulder.'+side]+vec(-sign*0.018,0,-0.012),
            (0.155,0.15,0.14),cloth,'UpperArm.'+side)
    sewn_pad('Knee sewn rim '+side,rest['Knee.'+side]+vec(0,.065,0),.135,.165,.025,webbing,'Shin.'+side)
    sewn_pad('Knee flexible shell '+side,rest['Knee.'+side]+vec(0,.083,0),.108,.134,.025,rubber,'Shin.'+side)
    cargo_pocket(side, sign)
# Weapon bone remains animated; Godot attaches the currently equipped model.
# The bind pose holds the weapon close to the chest. Fuse each sleeve separately
# so incidental arm/torso contact cannot become a stretched fabric bridge.
continuous_uniform(('Uniform torso', 'Trouser hips', 'Trouser thigh', 'Trouser shin',
                    'Knee.'), 'Continuous jacket and trousers')
for side in ('L', 'R'):
    continuous_uniform(('Sleeve '+side, 'Forearm '+side, 'Elbow.'+side,
                        'Shoulder.'+side), 'Continuous sleeve '+side)

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
    # Preserve the exact support exchange: positive cosine lift changes feet at
    # quarter cycles. Skipping these times interpolates two lifted feet through
    # the exchange, especially in the short run clip. Denser keys also reduce
    # curved knee-chain interpolation error without moving the character root.
    sample_frames = sorted(set(range(end_frame + 1)) |
                           {end_frame * 0.25, end_frame * 0.75})
    for frame in sample_frames:
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        progress = frame / end_frame
        parameters = dict(options)
        parameters['phase'] = progress * math.tau
        parameters['breath'] = math.sin(progress * math.tau) * (0.004 if 'crouch' in options else 0.006)
        if 'reload' in options:
            parameters['reload'] = progress
        if 'death' in options:
            parameters['death'] = min(1, progress * 1.35)
            parameters['breath'] = 0
        points = joints(**parameters)
        for name, start, end, _ in bones:
            pose = rig.pose.bones[name]
            old_direction = (rest[end] - rest[start]).normalized()
            new_direction = (points[end] - points[start]).normalized()
            delta = old_direction.rotation_difference(new_direction)
            # Preserve chest roll as well as direction. A shortest-arc
            # direction rotation alone discards twist around the weapon axis,
            # separating the magazine from the wrist during the belt reach.
            if 'reload' in options and (name in ('Hips', 'Spine', 'Head', 'Weapon')
                                       or name.startswith(('UpperArm.', 'Forearm.', 'Hand.'))):
                lean, _ = reload_lean(progress)
                local_direction = lean.inverted() @ new_direction
                delta = lean.to_quaternion() @ old_direction.rotation_difference(local_direction)
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
