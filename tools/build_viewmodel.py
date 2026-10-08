"""Original first-person sleeves/gloves and skeletal actions, in weapon-local meters."""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parent.parent
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
# The full asset builder runs this after the operator in the same Blender
# process. ACTIONS export otherwise reuses its orphaned skeleton animations.
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

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

def cloth_dye_pixels(base, twill=False):
    """Seamless dye/fibre variation, baked for glTF (no painted highlights)."""
    rng = random.Random(86)
    lattices = [(size, [rng.uniform(-1, 1) for _ in range(size*size)])
                for size in (4, 8, 16, 32)]
    pixels = []
    for y in range(256):
        for x in range(256):
            dye = 0
            for (size, values), amplitude in zip(lattices, (.10, .055, .03, .016)):
                u, w = x*size/256, y*size/256
                ix, iy = int(u), int(w)
                fx, fy = u-ix, w-iy
                fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
                def sample(a, b):
                    return values[(b % size)*size+a % size]
                dye += amplitude*((1-fy)*((1-fx)*sample(ix,iy)+fx*sample(ix+1,iy))
                                   +fy*((1-fx)*sample(ix,iy+1)+fx*sample(ix+1,iy+1)))
            # Dyed yarns vary across the weave. Sparse paired ripstop threads
            # remain subdued when mipmapped; avoid a high-contrast printed grid.
            yarn = .025*math.cos(math.tau*(x+y if twill else x)/4)
            yarn += .018*math.cos(math.tau*y/4)
            ripstop = 0 if twill else .035*(int(x % 32 in (0,2))+int(y % 32 in (0,2)))
            fleck = rng.uniform(-.022, .022)
            pixels.extend((*[c*(1+dye+yarn+ripstop+fleck) for c in base], 1))
    return pixels

cloth = material('Field sleeves', (0.19, 0.30, 0.27))
fabric = cloth.node_tree.nodes.new('ShaderNodeTexImage')
# Dry, unevenly dyed yarn breaks up broad cloth planes at first-person distance.
fabric.image = bpy.data.images.new('Sleeve olive dyed ripstop', width=256, height=256)
fabric.image.pixels = cloth_dye_pixels((.315,.325,.265))
fabric.image.pack()
cloth.node_tree.links.new(fabric.outputs['Color'], cloth.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
dry_weave = bpy.data.images.new('Sleeve dry cotton roughness', width=128, height=128)
dry_weave.colorspace_settings.name = 'Non-Color'
dry_weave.pixels = [c for y in range(128) for x in range(128)
    for c in (*([.94+.025*math.sin(x*.31)*math.sin(y*.23)
                   +.015*math.sin(math.pi*x/2)]*3),1)]
dry_weave.pack()
dry_node = cloth.node_tree.nodes.new('ShaderNodeTexImage')
dry_node.image = dry_weave
cloth.node_tree.links.new(dry_node.outputs['Color'],
                         cloth.node_tree.nodes['Principled BSDF'].inputs['Roughness'])
glove = material('Reinforced gloves', (0.055, 0.065, 0.048))
# Separate the woven back from the charcoal leather contact panels with actual
# exported dye pixels, rather than increasing normal-map noise.
glove_dye = bpy.data.images.new('Glove olive woven dye', width=256, height=256)
glove_dye.pixels = cloth_dye_pixels((.225, .235, .195), twill=True)
glove_dye.pack()
glove_color = glove.node_tree.nodes.new('ShaderNodeTexImage')
glove_color.image = glove_dye
glove.node_tree.links.new(glove_color.outputs['Color'],
                         glove.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
patch = material('Wrist straps', (0.045, 0.055, 0.035))
leather = material('Glove leather pads', (0.043, 0.050, 0.037))
leather.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.48
stitch = material('Glove subdued stitching', (.085, .092, .063))
# Brushed textile has broad, muted highlights; leather remains smoother.
# Bake the roughness field so the material survives Blender/glTF/Godot.
textile_grain = bpy.data.images.new('Glove brushed textile roughness', width=128, height=128)
textile_grain.colorspace_settings.name = 'Non-Color'
textile_grain.pixels = [c for y in range(128) for x in range(128)
    for c in (*([.83+.045*math.sin(x*.37)*math.sin(y*.29)
                  +.025*math.sin(x*math.pi/2+y*math.pi)]*3),1)]
textile_grain.pack()
textile_node=glove.node_tree.nodes.new('ShaderNodeTexImage')
textile_node.image=textile_grain
glove.node_tree.links.new(textile_node.outputs['Color'],
                         glove.node_tree.nodes['Principled BSDF'].inputs['Roughness'])
# Export actual texture pixels: procedural Blender nodes do not survive glTF.
# A low contrast grain breaks up the leather highlights without painted wear.
grain = bpy.data.images.new('Glove leather grain', width=128, height=128)
grain.colorspace_settings.name = 'Non-Color'
grain.pixels = [channel for y in range(128) for x in range(128)
                for channel in (*([.59 + .04 * math.sin(x*2.31+y*4.17)
                                    * math.sin(x*.79-y*1.73)]*3), 1)]
grain.pack()
grain_node = leather.node_tree.nodes.new('ShaderNodeTexImage')
grain_node.image = grain
leather.node_tree.links.new(grain_node.outputs['Color'],
                           leather.node_tree.nodes['Principled BSDF'].inputs['Roughness'])
# Tangent-space images survive glTF export. Textile and leather use different
# microstructure, with deliberately restrained amplitude at first-person scale.
for mat, label, strength in [(cloth, 'Sleeve ripstop weave', .075),
                             (glove, 'Glove woven backing', .016),
                             (leather, 'Glove fine leather', .025)]:
    normal_image = bpy.data.images.new(label, width=256, height=256)
    normal_image.colorspace_settings.name = 'Non-Color'
    pixels = []
    for y in range(256):
        for x in range(256):
            if mat == cloth:
                # Fine yarns plus sparse reinforcing threads. No baked light or
                # exaggerated fabric bumps: folds are carried by the mesh.
                dx = strength * math.sin(math.tau*x/4.0 + math.pi*y/2)
                dy = strength * math.sin(math.tau*y/4)
                dx += .035 * math.sin(math.tau*x/32)**15
                dy += .035 * math.sin(math.tau*y/32)**15
            elif mat == glove:
                dx = strength * math.sin(math.tau*x/8)
                dy = strength * math.sin(math.tau*y/8) * (.6+.4*math.cos(math.tau*x/16))
            else:
                dx = strength * math.sin(math.tau*(x*29+y*17)/256)
                dy = strength * math.cos(math.tau*(x*11-y*31)/256)
            normal = Vector((dx, dy, 1)).normalized()
            pixels.extend((normal.x*.5+.5, normal.y*.5+.5, normal.z*.5+.5, 1))
    normal_image.pixels = pixels
    normal_image.pack()
    texture = mat.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = normal_image
    normal_map = mat.node_tree.nodes.new('ShaderNodeNormalMap')
    mat.node_tree.links.new(texture.outputs['Color'], normal_map.inputs['Color'])
    mat.node_tree.links.new(normal_map.outputs['Normal'],
                           mat.node_tree.nodes['Principled BSDF'].inputs['Normal'])
seam = material('Sleeve stitching', (0.23, 0.26, 0.16))
# A sewn abrasion panel uses the same dry weave but a separately dyed fabric.
# Keep its normal/roughness textures so the export is fabric, not flat rubber.
reinforcement = cloth.copy()
reinforcement.name = 'Sleeve abrasion twill'
panel_dye = fabric.image.copy()
panel_dye.name = 'Sleeve reinforcement dyed twill'
panel_dye.pixels = cloth_dye_pixels((.255,.265,.215), twill=True)
panel_dye.pack()
reinforcement.node_tree.nodes[fabric.name].image = panel_dye
rest = {'Root': v(0,0,0), 'Up': v(0,0.1,0),
        'Elbow.L': v(-0.34,-0.32,0.17), 'Wrist.L': v(-0.055,-0.065,-0.18), 'Tip.L': v(0.015,-0.05,-0.2),
        'Elbow.R': v(0.28,-0.35,0.48), 'Wrist.R': v(0.015,-0.125,0.095), 'Tip.R': v(0.015,-0.08,0.06)}
# Shoulder anchors belong to the torso, independent of the sleeve surface.
# A swept-tube-derived anchor previously followed the elbow below the wrist,
# folding both bone segments into a large ball during magazine contact.
ELBOW_SWEEP = math.radians(65)
ELBOW_CURVE_RADIUS = .085

def solve_elbow(shoulder, wrist, pole, upper_length, lower_length):
    direction = wrist - shoulder
    distance = direction.length
    axis = direction.normalized()
    # Permit shoulder reach only outside the two-link workspace. Never scale
    # either bone or move the hand away from the authored weapon contact.
    reach = max(abs(upper_length-lower_length)+.001,
                min(distance, upper_length+lower_length-.001))
    shoulder = wrist - axis*reach
    across = pole-shoulder
    across -= axis*across.dot(axis)
    across.normalize()
    along = (upper_length**2-lower_length**2+reach**2)/(2*reach)
    elbow = shoulder + axis*along + across*math.sqrt(max(0, upper_length**2-along**2))
    return shoulder, elbow

for side, sign in [('L', -1), ('R', 1)]:
    # Bring the shoulder girdle toward the chest and give the humerus more
    # length than the forearm. Hand contacts stay in the weapon's coordinates.
    shoulder = v(sign*.22, -.43, .15 if side == 'L' else .35)
    shoulder, elbow = solve_elbow(shoulder, rest[f'Wrist.{side}'],
                                  v(sign*.45, -.60, .03), .33, .26)
    rest[f'Shoulder.{side}'] = shoulder
    rest[f'Elbow.{side}'] = elbow

bones = [('Root','Root','Up',None)]
for side in ['L','R']:
    bones += [(f'UpperArm.{side}',f'Shoulder.{side}',f'Elbow.{side}','Root'),
              (f'Forearm.{side}',f'Elbow.{side}',f'Wrist.{side}',f'UpperArm.{side}'),
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

def skin(obj, bone, mat, edge_mat=None):
    obj.data.materials.append(mat)
    if edge_mat is not None:
        obj.data.materials.append(edge_mat)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    obj.modifiers.new('Arm skin', 'ARMATURE').object = rig
    obj.parent = rig

def blend_wrist(obj, side):
    """Give overlapping cloth and glove the same spatial wrist deformation."""
    bpy.context.view_layer.update()
    wrist = rest[f'Wrist.{side}']
    axis = (wrist-rest[f'Elbow.{side}']).normalized()
    forearm = obj.vertex_groups.get(f'Forearm.{side}') or obj.vertex_groups.new(name=f'Forearm.{side}')
    hand = obj.vertex_groups.get(f'Hand.{side}') or obj.vertex_groups.new(name=f'Hand.{side}')
    for vertex in obj.data.vertices:
        distance = (obj.matrix_world @ vertex.co-wrist).dot(axis)
        u = max(0.0, min(1.0, (distance+.040)/.046))
        weight = u*u*(3-2*u)
        forearm.add([vertex.index], 1-weight, 'REPLACE')
        hand.add([vertex.index], weight, 'REPLACE')

def forearm_section(t):
    """Tailored sleeve sections, with shared tangents across each station.

    Width and depth follow separate anatomical landmarks. A single Bezier
    bulb made the elbow wide and the entire distal arm a straight cone.
    The flatter central section now carries volume toward the wrist, before
    a short gathered section meets the existing cuff seam.
    """
    # t, half-width, half-depth, width tangent, depth tangent (per unit t).
    sections = [
        (0.00, .044, .036, .024, .008),
        (0.25, .054, .047, .000, .000),
        (0.62, .053, .046, -.006, -.006),
        (0.84, .048, .039, -.030, -.032),
        (1.00, .0385, .028875, -.020, -.015),
    ]
    for a, b in zip(sections, sections[1:]):
        if t <= b[0]:
            span = b[0]-a[0]
            u = (t-a[0])/span
            h00, h10 = 2*u**3-3*u*u+1, u**3-2*u*u+u
            h01, h11 = -2*u**3+3*u*u, u**3-u*u
            return tuple(h00*a[k]+h10*span*a[k+2]
                         +h01*b[k]+h11*span*b[k+2] for k in (1, 2))
    return sections[-1][1:3]

for side in ['L','R']:
    start, end = rest[f'Elbow.{side}'], rest[f'Wrist.{side}']
    direction = end-start
    # Anatomical forearm under a loose sleeve. Localized diagonal creases leave
    # broad relaxed panels between the elbow and the gathered wrist, rather
    # than producing a corrugated tube with every ring at the same amplitude.
    vertices, faces = [], []
    rings, segments = 97, 64
    # The cuff starts 51 mm behind the wrist. End the sleeve at that seam,
    # rather than burying the tapered cuff inside a second, wider tube.
    # Both surfaces now share their boundary; skeleton/contact anchors stay put.
    length = direction.length - .051
    sleeve_center = (start + end)/2 - direction.normalized()*.0255
    for ring in range(rings):
        t = ring / (rings - 1)
        # Independent width/depth sections follow the two forearm bones and
        # proximal extensor mass. A single round radius inflated the entire
        # support arm, particularly in reload and the foreshortened ADS view.
        # Retain the cuff boundary and all skeleton/contact anchors.
        radius, depth = forearm_section(t)
        flatten = depth/radius
        # Bow the cloth over the extensor mass while leaving both rig endpoints
        # fixed. Carry relaxed fabric volume into the short gathered wrist.
        bow = math.sin(math.pi*t)**2
        center_x = (-.004 if side == 'L' else .004)*bow
        center_y = -.005*bow
        for j in range(segments):
            angle = j * math.tau / segments
            # Stage96: one coherent fold field. Broad cloth panels end in
            # narrow compression valleys; avoid stacking several rounded
            # Gaussian fields, which inflated the silhouette into a hose.
            phase = angle + .45*t + (.35 if side == 'R' else 0)
            tension = math.sin(math.pi*t)**1.3
            drape = tension*(.003*math.cos(3*phase) + .0015*math.sin(5*phase))
            fold = 0.0
            for position, facing, slope, width, height in [
                (.30, 4.9, .13, .080, .008),
                (.51, 5.3, -.13, .070, .010),
                (.70, 4.7, .10, .050, .009),
                (.84, 5.2, -.065, .032, .007),
                (.42, 1.8, -.12, .080, .007),
                (.65, 2.5, .10, .055, .008),
                (.82, 1.9, -.07, .035, .006),
            ]:
                facing += .35 if side == 'R' else 0
                angular = math.exp((math.cos(angle-facing)-1)*1.8)
                distance = (t-position-slope*math.sin(angle-facing))/width
                # Broad compressed cotton valleys avoid razor-like cuts at the wrist.
                # Cloth folds compress a sleeve, not the whole underlying arm.
                # Keep the broad extensor panel readable in grazing light.
                fold += .65*height*angular*(.65*math.exp(-(distance/1.2)**2)
                    - math.exp(-((distance-.55)/.48)**2)
                    + .14*math.exp(-((distance-1.12)/.44)**2))
            for facing in (.7, 2.7, 4.4):
                delta = math.atan2(math.sin(phase-facing),math.cos(phase-facing))
                drape -= .0025*math.exp(-(delta/.25)**2)*tension
            cuff_blend = max(0, min(1, (t-.90)/.10))
            cuff_blend = cuff_blend*cuff_blend*(3-2*cuff_blend)
            radius_here = radius + (fold + drape)*(1-cuff_blend)
            local_flatten = flatten
            # Round, asymmetric extensor/flexor masses replace the four flat
            # longitudinal panels. Their fullness ends before the wrist, so the
            # whole forearm tapers rather than stepping into an abrupt cuff.
            # Zero envelope at both seams preserves the shared elbow/cuff mesh.
            muscle = math.sin(math.pi*t)**1.4*(1-cuff_blend)
            radial_side = 0.35 if side == 'R' else math.pi-.35
            radius_here += muscle*(.004*math.cos(angle-radial_side)
                                   + .002*math.cos(2*(angle-1.1)))
            panel_x = math.cos(angle)
            panel_y = math.sin(angle)
            # Follow the anatomical ellipse. Broad planes come from the
            # localized cloth field above, not a squared-off cross-section
            # running the full length of the forearm.
            vertices.append((center_x + panel_x*radius_here,
                             center_y + panel_y*radius_here*local_flatten,
                             (t-0.5)*length))
    for ring in range(rings-1):
        for j in range(segments):
            n = (j+1)%segments
            faces.append((ring*segments+j,ring*segments+n,(ring+1)*segments+n,(ring+1)*segments+j))
    # Continue the SAME elbow boundary around a bent elbow into the upper arm.
    # The wrist and 30 cm forearm rig remain fixed. Parallel-transported rings
    # turn towards the torso, rather than lengthening the forearm cylinder or
    # plugging its visible opening with a flat disc.
    sleeve_rotation = Vector((0,0,1)).rotation_difference(direction.normalized())
    down_local = sleeve_rotation.inverted() @ v(0, -1, 0)
    bend_axis = Vector((down_local.x, down_local.y, 0)).normalized()
    elbow_center = Vector((0, 0, -length/2))
    previous_ring = 0
    fabric_v = [(i/(rings-1))*4.68*direction.length/.519 for i in range(rings)]
    elbow_radius = ELBOW_CURVE_RADIUS
    bend_angle = ELBOW_SWEEP
    # Stage420: sleeve centreline follows the actual upper-arm bone, rather
    # than an offset swept pipe. The elbow is the shared joint, not the end
    # of an extra 8.5 cm arc which balloons under two-bone deformation.
    shoulder_local = sleeve_rotation.inverted() @ (rest[f'Shoulder.{side}']-sleeve_center)
    upper_axis = shoulder_local-elbow_center
    tangent = upper_axis.normalized()
    for k in range(1, 49):
        t_upper = k/48
        distance = upper_axis.length*t_upper
        # Match the forearm centreline tangent at the shared elbow boundary.
        # Previously centres immediately followed the humerus while sections
        # stayed perpendicular to the forearm: the resulting wedge produced
        # a bright circumferential ridge under reload deformation.
        # One continuous cubic from elbow to shoulder. The former compact
        # correction reversed its tangent contribution mid-transition, making
        # an S-shaped centreline and a pinched band under elbow skinning.
        # Control handles keep the elbow tangent continuous with the forearm
        # and settle onto the humerus without a second inflection.
        handle = upper_axis.length*.28
        p0 = elbow_center
        p1 = p0 + Vector((0, 0, -handle))
        p3 = shoulder_local
        p2 = p3 - tangent*handle
        u = t_upper
        center = ((1-u)**3*p0 + 3*(1-u)**2*u*p1
                  + 3*(1-u)*u*u*p2 + u**3*p3)
        curve_tangent = (3*(1-u)**2*(p1-p0)
                         + 6*(1-u)*u*(p2-p1)
                         + 3*u*u*(p3-p2)).normalized()
        # Separate elbow, triceps and deltoid sections instead of inflating
        # the entire upper arm into a spherical shoulder.
        upper_sections = [(0, .044, .036), (.22, .049, .040),
                          (.55, .054, .045), (.82, .057, .049),
                          (1, .053, .047)]
        for (a, wa, da), (b, wb, db) in zip(upper_sections, upper_sections[1:]):
            if a <= u <= b:
                f = (u-a)/(b-a)
                f = f*f*(3-2*f)
                radius = wa+(wb-wa)*f
                upper_flatten = (da+(db-da)*f)/radius
                break
        # Sections follow the actual curve, then the straight humeral shaft.
        section_axis = -curve_tangent
        orientation = Vector((0,0,1)).rotation_difference(section_axis)
        current_ring = len(vertices)//segments
        for j in range(segments):
            angle = j*math.tau/segments
            # Shallow compression folds at the inner elbow, broad upper sleeve.
            r = radius + .0025*math.sin(distance*62+angle*2)*math.sin(math.pi*k/48)
            section = Vector((math.cos(angle)*r, math.sin(angle)*r*upper_flatten, 0))
            # Shape the antecubital crease as a flattened fabric panel rather
            # than a circular hose. Fade in/out to keep both joins continuous.
            if k <= 24:
                compression = math.sin(math.pi*k/24)**2
                inward = max(0.0, section.dot(bend_axis))
                section -= bend_axis*inward*.32*compression
            point = center + orientation @ section
            vertices.append(tuple(point))
        fabric_v.append(-distance*4.68/.519)
        for j in range(segments):
            n = (j+1)%segments
            faces.append((previous_ring+n, previous_ring+j, current_ring*segments+j, current_ring*segments+n))
        previous_ring = current_ring*segments
    # Rounded shoulder closure lies beyond the bend; no planar elbow cap.
    shoulder_center = center.copy()
    for k in range(1, 9):
        angle = k*math.pi/18
        center = shoulder_center + tangent*.068*math.sin(angle)
        current_ring = len(vertices)//segments
        for j in range(segments):
            a = j*math.tau/segments
            vertices.append(tuple(center + orientation @ Vector((math.cos(a)*radius*math.cos(angle), math.sin(a)*radius*.90*math.cos(angle), 0))))
        fabric_v.append(-(distance+.068*angle)*4.68/.519)
        for j in range(segments):
            n = (j+1)%segments
            faces.append((previous_ring+n,previous_ring+j,current_ring*segments+j,current_ring*segments+n))
        previous_ring = current_ring*segments
    tip = len(vertices)
    vertices.append(tuple(shoulder_center+tangent*.068))
    for j in range(segments):
        faces.append((previous_ring+(j+1)%segments,previous_ring+j,tip))
    print(f'SLEEVE_CONTINUITY_PASS side={side} forearm_m={direction.length:.3f} elbow_bend_deg={math.degrees(ELBOW_SWEEP):.0f} shared_boundary=64 shoulder=rounded')
    mesh = bpy.data.meshes.new('Tailored sleeve folds')
    mesh.from_pydata(vertices, [], faces);mesh.update()
    uv = mesh.uv_layers.new(name='Fabric UV')
    for polygon in mesh.polygons:
        polygon.use_smooth = True
        for loop_index in polygon.loop_indices:
            index = mesh.loops[loop_index].vertex_index
            u = (index % segments) / segments
            if polygon.index % segments == segments-1 and u == 0: u = 1
            # Match a roughly 4 cm camouflage patch to the forearm instead of
            # stretching a torso-sized print across its circumference.
            uv.data[loop_index].uv = (u*2.6, fabric_v[min(index//segments,len(fabric_v)-1)])
    sleeve = bpy.data.objects.new(f'Sleeve.{side}',mesh)
    bpy.context.collection.objects.link(sleeve)
    sleeve.location = sleeve_center
    sleeve.rotation_mode = 'QUATERNION'
    sleeve.rotation_quaternion = Vector((0,0,1)).rotation_difference(direction.normalized())
    skin(sleeve, f'Forearm.{side}', cloth)
    upper_group = sleeve.vertex_groups.new(name=f'UpperArm.{side}')
    lower_group = sleeve.vertex_groups[f'Forearm.{side}']
    for index in range(len(vertices)):
        # Spread rotation over both sides of the elbow seam. The sewn panel
        # starts at ring eight and remains outside this deformation region.
        ring = index//segments
        # Skin across equal physical distances on both sides of the joint;
        # ring counts differ between forearm and upper arm.
        joint_distance = (upper_axis.length*(ring-rings+1)/48
                          if ring >= rings else -length*ring/(rings-1))
        weight = max(0.0, min(1.0, .5 + joint_distance/.100))
        weight = weight*weight*(3-2*weight)
        lower_group.add([index], 1-weight, 'REPLACE')
        upper_group.add([index], weight, 'REPLACE')
    # Sewn reinforcement panel follows the actual folds, rather than floating
    # as a rigid box over the elbow. Its bound perimeter has a cloth thickness.
    panel_vertices=[];panel_faces=[]
    first_ring,last_ring=8,55
    first_segment,last_segment=7,29
    for k in range(first_ring,last_ring+1):
        for j in range(first_segment,last_segment+1):
            x,y,z=vertices[k*segments+j]
            panel_vertices.append((x*1.025,y*1.025,z))
    columns=last_segment-first_segment+1
    for k in range(last_ring-first_ring):
        for j in range(columns-1):
            a=k*columns+j
            panel_faces.append((a,a+1,a+columns+1,a+columns))
    panel_mesh=bpy.data.meshes.new('Fold conforming sleeve reinforcement')
    panel_mesh.from_pydata(panel_vertices,[],panel_faces);panel_mesh.update()
    panel_uv=panel_mesh.uv_layers.new(name='Fabric UV')
    for polygon in panel_mesh.polygons:
        polygon.use_smooth=True
        for loop_index in polygon.loop_indices:
            index=panel_mesh.loops[loop_index].vertex_index
            panel_uv.data[loop_index].uv=((first_segment+index%columns)/segments*2.6,
                                         (first_ring+index//columns)/(rings-1)*4.68*direction.length/.519)
    panel=bpy.data.objects.new(f'Sleeve reinforcement.{side}',panel_mesh)
    bpy.context.collection.objects.link(panel)
    panel.location=sleeve.location;panel.rotation_mode='QUATERNION'
    panel.rotation_quaternion=sleeve.rotation_quaternion
    backing=panel.modifiers.new('Bound fabric thickness','SOLIDIFY')
    backing.thickness=.0012
    # Solidify's narrow cut edge has collapsed UVs; give that bound edge the
    # untextured seam material instead of sampling a stretched twill texture.
    backing.material_offset_rim = 1
    skin(panel,f'Forearm.{side}',reinforcement,seam)
    # Copy the underlying cloth weights, including vertices made by Solidify.
    # A rigid reinforcement used to separate from the blended elbow surface
    # during reload, even though the resting mesh followed the sleeve exactly.
    panel_lower = panel.vertex_groups[f'Forearm.{side}']
    panel_upper = panel.vertex_groups.new(name=f'UpperArm.{side}')
    for vertex in panel.data.vertices:
        distance_from_elbow = vertex.co.z + length/2
        weight = max(0.0, min(1.0, .5-distance_from_elbow/.100))
        weight = weight*weight*(3-2*weight)
        panel_lower.add([vertex.index], 1-weight, 'REPLACE')
        panel_upper.add([vertex.index], weight, 'REPLACE')
    # The reinforcement must read as a sewn fabric panel in motion. Trace its
    # perimeter over the same sampled folds, avoiding a floating rigid pad.
    border = bpy.data.curves.new('Reinforcement topstitch', 'CURVE')
    border.dimensions = '3D'
    border.bevel_depth = .00065
    border.bevel_resolution = 2
    boundary = ([j for j in range(columns)]
                + [k*columns+columns-1 for k in range(1,last_ring-first_ring+1)]
                + [(last_ring-first_ring)*columns+j for j in range(columns-2,-1,-1)]
                + [k*columns for k in range(last_ring-first_ring-1,0,-1)])
    line = border.splines.new('POLY')
    line.points.add(len(boundary)-1)
    line.use_cyclic_u = True
    for point,index in zip(line.points,boundary):
        x,y,z = panel_vertices[index]
        point.co = (x*1.012,y*1.012,z,1)
    trim = bpy.data.objects.new(f'Reinforcement stitching.{side}',border)
    bpy.context.collection.objects.link(trim)
    trim.location=sleeve.location
    trim.rotation_mode='QUATERNION'
    trim.rotation_quaternion=sleeve.rotation_quaternion
    bpy.ops.object.select_all(action='DESELECT')
    trim.select_set(True);bpy.context.view_layer.objects.active=trim
    bpy.ops.object.convert(target='MESH')
    trim = bpy.context.object
    skin(trim,f'Forearm.{side}',seam)
    trim_lower = trim.vertex_groups[f'Forearm.{side}']
    trim_upper = trim.vertex_groups.new(name=f'UpperArm.{side}')
    for vertex in trim.data.vertices:
        distance_from_elbow = vertex.co.z + length/2
        weight = max(0.0, min(1.0, .5-distance_from_elbow/.100))
        weight = weight*weight*(3-2*weight)
        trim_lower.add([vertex.index], 1-weight, 'REPLACE')
        trim_upper.add([vertex.index], weight, 'REPLACE')
    # Soft tapered cuff: elliptical wrist opening, gathered cloth and rolled
    # hems rather than a rigid circular bracelet. Local Z follows the sleeve.
    cuff_vertices=[];cuff_faces=[]
    def cuff_radius(z, angle):
        t=max(0,min(1,(z+.025)/.052))
        # Continue the sleeve's distal tangent into the cuff, then flatten
        # toward the glove. A zero-slope smoothstep here made a hard collar.
        seam_radius = forearm_section(1.0)[0]
        seam_slope = (seam_radius-forearm_section(1.0-1e-5)[0])/1e-5
        start_tangent = seam_slope / length * .052
        radius = ((2*t**3-3*t*t+1)*seam_radius
                  +(t**3-2*t*t+t)*start_tangent
                  +(-2*t**3+3*t*t)*.030)
        gather=1+(.035*math.cos(angle*5+.4)+.015*math.sin(angle*3))*math.sin(t*math.pi)
        return radius*gather
    cuff_rings=[(-.025+.052*k/24,0) for k in range(25)]
    for k,(z,radius) in enumerate(cuff_rings):
        for j in range(40):
            angle=j*math.tau/40
            # Uneven fabric compression at the fastening; restrained hem
            # thickness avoids a rigid ring around the wrist.
            radius=cuff_radius(z,angle)
            cuff_vertices.append((math.cos(angle)*radius,
                                  math.sin(angle)*radius*.75,z))
    for k in range(len(cuff_rings)-1):
        for j in range(40):
            nj=(j+1)%40
            cuff_faces.append((k*40+j,k*40+nj,(k+1)*40+nj,(k+1)*40+j))
    cuff_mesh=bpy.data.meshes.new('Gathered wrist fabric')
    cuff_mesh.from_pydata(cuff_vertices,[],cuff_faces);cuff_mesh.update()
    uv = cuff_mesh.uv_layers.new(name='Fabric UV')
    for polygon in cuff_mesh.polygons:
        polygon.use_smooth=True
        for loop_index in polygon.loop_indices:
            index=cuff_mesh.loops[loop_index].vertex_index
            u=(index%40)/40
            if polygon.index%40 == 39 and u == 0: u=1
            uv.data[loop_index].uv=(u,index//40/(len(cuff_rings)-1)*.16)
    cuff=bpy.data.objects.new(f'Tailored cuff.{side}',cuff_mesh)
    bpy.context.collection.objects.link(cuff)
    cuff.location=end-direction.normalized()*.026
    cuff.rotation_mode='QUATERNION';cuff.rotation_quaternion=sleeve.rotation_quaternion
    skin(cuff, f'Forearm.{side}', cloth)
    blend_wrist(cuff, side)
    # Curved overlapping fabric adjustment tab, with a thin bound edge.
    for label, inset, lift, mat in [('binding', 0, .0005, patch),
                                    ('face', .045, .0009, cloth)]:
        tab_vertices=[];tab_faces=[]
        for row in range(9):
            z=(-.014+inset*.1)+(.028-inset*.2)*row/8
            for j in range(17):
                angle=.35+inset+(1.70-2*inset)*j/16
                radius=cuff_radius(z,angle)+lift
                tab_vertices.append((math.cos(angle)*radius,math.sin(angle)*radius*.75,z))
        for row in range(8):
            for j in range(16):
                a=row*17+j
                tab_faces.append((a,a+1,a+18,a+17))
        tab_mesh=bpy.data.meshes.new('Cuff tab '+label)
        tab_mesh.from_pydata(tab_vertices,[],tab_faces);tab_mesh.update()
        tab_uv=tab_mesh.uv_layers.new(name='Fabric UV')
        for polygon in tab_mesh.polygons:
            polygon.use_smooth=True
            for loop_index in polygon.loop_indices:
                index=tab_mesh.loops[loop_index].vertex_index
                tab_uv.data[loop_index].uv=(index%17/16*.25,index//17/8*.10)
        tab=bpy.data.objects.new(f'Cuff tab {label}.{side}',tab_mesh)
        bpy.context.collection.objects.link(tab)
        tab.location=cuff.location;tab.rotation_mode='QUATERNION'
        tab.rotation_quaternion=cuff.rotation_quaternion
        skin(tab,f'Forearm.{side}',mat)
        blend_wrist(tab, side)
    # Raised sewn piping along the outer sleeve, following the tailored surface.
    curve=bpy.data.curves.new('Double sewn seam','CURVE');curve.dimensions='3D'
    curve.bevel_depth=.0012;curve.bevel_resolution=2
    for angle in [0.3,0.46]:
        line=curve.splines.new('POLY');line.points.add(rings-1)
        for k,point in enumerate(line.points):
            j=round(angle/math.tau*segments)%segments
            x,y,z=vertices[k*segments+j]
            point.co=(x*1.015,y*1.015,z,1)
    piping=bpy.data.objects.new(f'Sleeve seam.{side}',curve);bpy.context.collection.objects.link(piping)
    piping.location=sleeve.location;piping.rotation_mode='QUATERNION';piping.rotation_quaternion=sleeve.rotation_quaternion
    bpy.ops.object.select_all(action='DESELECT');piping.select_set(True);bpy.context.view_layer.objects.active=piping
    bpy.ops.object.convert(target='MESH');skin(bpy.context.object,f'Forearm.{side}',seam)
    # Continuous tapered glove volumes; fingers sweep around the fore-end/grip.
    # Dimensions below are in Godot coordinates, as are the skeleton rest points.
    before_hand=set(bpy.context.scene.objects)
    def grasp_point(point):
        # Evaluate in the authored hand frame, before the proximal wrist sweep.
        # World Z after that sweep is not the longitudinal hand coordinate.
        if side != 'R':
            return point.copy()
        delta = point - end
        x, y, z = delta.x, delta.z, -delta.y
        blend = max(0., min(1., (.035-z)/.060))
        blend = blend*blend*(3.-2.*blend)
        target = v(y+.026, -x*1.20+.023, z*.40+.023)
        return end + delta.lerp(target, blend)

    def oval(name, center, size, mat):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=end+v(*center))
        obj=bpy.context.object; obj.name=f'{name}.{side}'
        obj.scale=(size[0],size[2],size[1])
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        for polygon in obj.data.polygons: polygon.use_smooth=True
        skin(obj,f'Hand.{side}',mat)

    def curled_digit(name, centers, radii, thumb=False):
        # Catmull-Rom centerline gives continuous phalanges instead of stacked beads.
        controls=[Vector(p) for p in centers]
        samples=[]
        for k in range(len(controls)-1):
            p0=controls[max(0,k-1)];p1=controls[k]
            p2=controls[k+1];p3=controls[min(len(controls)-1,k+2)]
            for j in range(6):
                t=j/6
                if thumb:
                    # Shared, bounded tangents round the joint without moving
                    # the grip endpoints or overshooting the contact envelope.
                    before=p1-p0; segment=p2-p1; after=p3-p2
                    m1=(p2-p0).normalized()*min(segment.length,before.length or segment.length)*.65
                    m2=(p3-p1).normalized()*min(segment.length,after.length or segment.length)*.65
                    point=(2*t**3-3*t*t+1)*p1+(t**3-2*t*t+t)*m1+(-2*t**3+3*t*t)*p2+(t**3-t*t)*m2
                else:
                    point=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
                samples.append((point,radii[k]*(1-t)+radii[k+1]*t))
        # Keep the grip endpoint fixed, but give the distal phalanx a padded
        # rounded end instead of tapering the whole final segment to a needle.
        # The shallow dome sits behind that endpoint to preserve clearance.
        tip_direction=(controls[-1]-controls[-2]).normalized()
        cap_depth=radii[-1]*.7
        cap_center=controls[-1]-tip_direction*cap_depth
        # Reparameterize the last segment to meet the dome without doubling
        # back (which would fold the surface and its normals).
        for index in range(len(samples)-6,len(samples)):
            amount=(index-(len(samples)-6))/6
            point,radius=samples[index]
            samples[index]=(point-tip_direction*cap_depth*amount,radius)
        samples.append((cap_center,radii[-1]))
        for step in range(1,7):
            angle=(math.pi*.5)*step/6
            samples.append((cap_center+tip_direction*cap_depth*math.sin(angle),
                            max(.0001,radii[-1]*math.cos(angle))))
        verts=[];faces=[];n=24
        previous_across = None
        for k,(point,radius) in enumerate(samples):
            tangent=(samples[min(k+1,len(samples)-1)][0]-samples[max(0,k-1)][0]).normalized()
            # Parallel transport avoids the old frame flip at tangent.x=.9.
            # A stable frame also keeps the palm-side leather on one side of
            # each digit instead of spiralling around a sharply bent thumb.
            if previous_across is None:
                reference=Vector((1,0,0)) if abs(tangent.x)<.9 else Vector((0,1,0))
                across=tangent.cross(reference).normalized()
            else:
                across=(previous_across-tangent*previous_across.dot(tangent)).normalized()
            previous_across=across
            up=tangent.cross(across).normalized()
            for j in range(n):
                angle=j*math.tau/n
                t = k / (len(samples)-1)
                # Compressed flexion bands interrupt the smooth hose silhouette.
                # Only indent the existing envelope, preserving grip clearance.
                compression = sum(math.exp(-((t-joint)/.029)**2)
                                  for joint in ((.43,.72) if thumb else (.32,.63,.79)))
                # Narrow phalangeal shafts between fuller joints. Flatten the
                # gripping pad, retaining the original outer contact envelope.
                shaft = (.045 if thumb else .10)*math.sin(t*math.pi*(2 if thumb else 3))**2
                radius_here = radius * (1-shaft-.10*compression)
                cosine, sine = math.cos(angle), math.sin(angle)
                cross_x=math.copysign(abs(cosine)**.82,cosine)
                cross_y=math.copysign(abs(sine)**.82,sine)
                flatten = (.80-.22*t) if thumb else .65
                if thumb:
                    # Oval glove sections retain pad thickness without the
                    # rectangular dorsal corners of the earlier thumb mesh.
                    # Keep a shallow IP crease between padded phalanges.
                    hinge = math.exp(-((t-.50)/.065)**2)
                    shaft_waist = math.exp(-((t-.29)/.15)**2)
                    radius_here *= 1-.12*shaft_waist
                    cross_x=math.copysign(abs(cosine)**.90,cosine)
                    cross_y=math.copysign(abs(sine)**.90,sine)
                    flatten=.62+.06*hinge
                    cross_y *= 1-.22*hinge*max(0.,-sine)
                position=point+radius_here*(across*cross_x+up*cross_y*flatten)
                verts.append(end+v(*position))
        for k in range(len(samples)-1):
            for j in range(n):
                nj=(j+1)%n
                faces.append((k*n+j,k*n+nj,(k+1)*n+nj,(k+1)*n+j))
        faces.extend([tuple(reversed(range(n))),tuple((len(samples)-1)*n+j for j in range(n))])
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
        uv = mesh.uv_layers.new(name='GloveUV')
        for polygon in mesh.polygons:
            indices = list(polygon.vertices)
            seam_face = any(index % n == 0 for index in indices) and any(index % n == n-1 for index in indices)
            for loop_index, index in zip(polygon.loop_indices, indices):
                u = (index % n)/n
                if seam_face and index % n == 0:
                    u = 1.0
                uv.data[loop_index].uv = (u, (index//n)/(len(samples)-1))
        for polygon in mesh.polygons: polygon.use_smooth=True
        obj=bpy.data.objects.new(f'{name}.{side}',mesh);bpy.context.collection.objects.link(obj)
        skin(obj,f'Hand.{side}',glove)
        # Sewn grip leather is part of the digit surface, rather than floating
        # oval pads. Textile sidewalls and flex channels remain exposed.
        mesh.materials.append(leather)
        for polygon in mesh.polygons:
            if polygon.index >= (len(samples)-1)*n:
                continue
            ring, sector = divmod(polygon.index,n)
            t = ring/(len(samples)-1)
            flex = any(abs(t-joint)<.035 for joint in ((.43,.72) if thumb else (.32,.63,.79)))
            if 2 <= sector <= n//2-3 and .08 < t < .91 and not flex:
                polygon.material_index=1

    mirror=-1 if side=='R' else 1
    # Tailored glove body: a narrow wrist opens into a rounded metacarpal
    # arch. The support palm cups inward instead of forming a flat panel.
    # Keep the finger roots and contact envelope in their original positions.
    palm_sections = [
        (.040,.024,.018), (.032,.0245,.0185), (.025,.025,.019),
        (.018,.025,.0195), (.010,.025,.020), (.002,.028,.023),
        (-.005,.030,.025), (-.015,.032,.026), (-.025,.033,.027),
        (-.035,.033,.026), (-.044,.032,.023),
        (-.052,.029,.020), (-.060,.025,.016), (-.070,.012,.007)]
    palm_vertices=[];palm_faces=[]
    n=48
    for k,(z,width,depth) in enumerate(palm_sections):
        for j in range(n):
            angle=j*math.tau/n
            # Oval metacarpal arch replaces the flat superellipse panel.
            # Cup the support palm toward its longitudinal finger row.
            x=math.cos(angle)*width
            y=math.sin(angle)*depth
            cup=math.exp(-((z+.025)/.037)**4)
            if side == 'L':
                # The metacarpals reach the finger roots: a cupped, asymmetric
                # palm, rather than a small oval with four long tubes attached.
                x=x*(1+.12*cup)+.016*cup
                y+=.006*cup*(x/width)
            x+=mirror*.002*math.sin(k/(len(palm_sections)-1)*math.pi)
            # Small gathered creases where the fabric bends at the wrist.
            crease=1-.055*math.cos(angle*5+.7)*math.exp(-((z-.015)/.018)**2)
            # Cloth follows shallow metacarpal ridges instead of floating
            # protective ellipsoids. Fade into the wrist and finger roots.
            dorsal_sign=-1 if side=='L' else 1
            dorsal=max(0,dorsal_sign*math.sin(angle))**4
            # Flatten the back of the hand without moving the grip surface.
            y-=dorsal_sign*.012*dorsal*cup
            if side == 'L':
                # Wrap the palm edges around the fore-end; fade the transverse
                # arch into the existing wrist and finger contact anchors.
                arch=min(1.,abs((x-.006)/(.78*width)))**2
                y+=.008*cup*arch
                thenar=math.exp(-((x-.015)/.013)**2-((z+.018)/.025)**2)
                y+=.0035*thenar*max(0.,math.sin(angle))**3
            # Tendons fan out from the wrist into individual metacarpals.
            # Broad, low knuckles remain part of the cloth surface; the
            # gripping side and finger contact paths are unchanged.
            fan=max(0,min(1,(.015-z)/.055))
            ridge=sum(math.exp(-((x-center*(.45+.55*fan))/.0045)**2)
                      for center in (-.017,0,.017))
            y+=dorsal_sign*.0018*ridge*dorsal*math.exp(-((z+.024)/.030)**4)
            knuckles=sum(math.exp(-((x-center)/.008)**2
                                  -((z+.043-abs(center)*.25)/.010)**2)
                         for center in (-.017,0,.017))
            y+=dorsal_sign*.0028*knuckles*dorsal
            # Two compressed folds across the back of the bent wrist,
            # fading at the sides instead of encircling it like bracelets.
            folds=(math.exp(-((z-.012-x*.18)/.0035)**2)
                   +.7*math.exp(-((z-.024+x*.12)/.003)**2))
            y-=dorsal_sign*.0014*folds*dorsal
            palm_vertices.append(end+v(x*crease,y*crease,z))
    for k in range(len(palm_sections)-1):
        for j in range(n):
            # Sections run toward negative Z: their winding is the opposite
            # of the finger sweeps. Inward faces made the visible palm look
            # hollow, with a hard dark panel even after silhouette changes.
            palm_faces.append((k*n+j,(k+1)*n+j,
                               (k+1)*n+(j+1)%n,k*n+(j+1)%n))
    wall_count=len(palm_faces)
    palm_faces.extend([tuple(range(n)),
                       tuple(reversed([(len(palm_sections)-1)*n+j for j in range(n)]))])
    palm_mesh=bpy.data.meshes.new('Anatomical glove wrist and palm')
    palm_mesh.from_pydata(palm_vertices,[],palm_faces);palm_mesh.update()
    # Check actual generated face normals, not just the face-index formula.
    # This guards against another coordinate/winding regression on either hand.
    for polygon in list(palm_mesh.polygons)[:wall_count]:
        center=sum((palm_mesh.vertices[i].co for i in polygon.vertices),Vector())/4
        radial=center-end
        radial.y=0  # Blender Y is the longitudinal Godot Z axis.
        assert polygon.normal.dot(radial)>0, f'Inward palm face: {side}/{polygon.index}'
    print(f'PALM_NORMALS_PASS side={side} outward_faces={wall_count} closed_ends=2')
    # Preserve authored ring identity through the grasp, then bend the root.
    for vertex in palm_mesh.vertices:
        vertex.co = grasp_point(vertex.co)
    # Bend only authored proximal palm rings, before fingers join the mesh.
    # A spatial selection after union also catches curled fingertips and
    # turns the grasp into a loop. Ring identity preserves contact geometry.
    wrist_axis = (end - rest[f'Elbow.{side}']).normalized()
    # Sweep cross sections along a tangent-continuous wrist centerline.
    # Rotating each complete ring about the joint also rotated its center,
    # compressing the inside of the bend into a pinched, abrupt hinge.
    proximal_axis = v(0, 0, 1)
    root_start = proximal_axis * .010
    root_end = -wrist_axis * .040
    root_start_tangent = proximal_axis * .030
    root_end_tangent = -wrist_axis * .030
    aligned_vertices = 0
    for ring_index, (axial, width, depth) in enumerate(palm_sections):
        amount = max(0., min(1., (axial - .010) / .030))
        if amount <= 0:
            continue
        t = amount
        center = ((2*t**3-3*t*t+1)*root_start
                  +(t**3-2*t*t+t)*root_start_tangent
                  +(-2*t**3+3*t*t)*root_end
                  +(t**3-t*t)*root_end_tangent)
        tangent = ((6*t*t-6*t)*root_start
                   +(3*t*t-4*t+1)*root_start_tangent
                   +(-6*t*t+6*t)*root_end
                   +(3*t*t-2*t)*root_end_tangent)
        assert tangent.length > .001, f'Degenerate wrist sweep: {side}/{ring_index}'
        rotation = proximal_axis.rotation_difference(tangent.normalized())
        for vertex in list(palm_mesh.vertices)[ring_index*n:(ring_index+1)*n]:
            radial = vertex.co - end - proximal_axis * axial
            vertex.co = end + center + rotation @ radial
            aligned_vertices += 1
    palm_mesh.update()
    print(f'PALM_ROOT_FRAME_PASS side={side} vertices={aligned_vertices} fingers_excluded=True')
    palm_mesh.materials.append(glove)
    palm_mesh.materials.append(leather)
    palm_uv=palm_mesh.uv_layers.new(name='GloveUV')
    for polygon in palm_mesh.polygons:
        polygon.use_smooth=True
        ring,sector=divmod(polygon.index,n)
        # The hand back is continuous textile, not a dark rectangular plate.
        # Leather protection is supplied by the individual knuckle pads below.
        for li in polygon.loop_indices:
            index=palm_mesh.loops[li].vertex_index
            if polygon.index >= wall_count:
                angle=(index%n)*math.tau/n
                palm_uv.data[li].uv=(.5+.5*math.cos(angle),.5+.5*math.sin(angle))
                continue
            u=(index%n)/n
            if polygon.index%n==n-1 and u==0: u=1
            palm_uv.data[li].uv=(u,index//n/(len(palm_sections)-1))
    palm=bpy.data.objects.new(f'Tapered palm.{side}',palm_mesh)
    bpy.context.collection.objects.link(palm)
    subdivision=palm.modifiers.new('Soft glove tailoring','SUBSURF')
    subdivision.levels=2
    skin(palm,f'Hand.{side}',glove)
    if side == 'L':
        # Support fingers lie across the bore axis, cupping the underside of
        # the 50–59 mm fore-end. Coordinates remain relative to the same palm
        # anchor used by the runtime magazine-contact solver.
        # The thumb saddle merges into the palm rather than forming a ball
        # between the wrist and thumb. Its flatter profile reveals the cleft.
        oval('Support thenar web',(.005,.019,-.024),(.016,.012,.026),glove)
        for i in range(4):
            z = -.056 + i * .019
            r = [.009,.0095,.009,.0078][i]
            # Index/middle/ring/little fingers form a stepped grip arch.
            # Shorten the little finger at the proximal joint as well as
            # the tip; scaling only the tip left four parallel hose shapes.
            reach = [.94,1.0,.91,.73][i]
            spread = [-.003,0,.002,.006][i]
            # MCP roots emerge from the broad palm. Short proximal/distal
            # phalanges turn at two joints around the fore-end; the endpoints
            # retain the existing weapon and magazine contact locations.
            curled_digit(f'Support wrap finger {i}',[
                (.024*reach,-.001,z),(.044*reach,-.009,z+spread*.3),
                (.064*reach,-.012,z+spread*.7),
                (.081*reach,-.003,z+spread),(.094*reach,.014,z+spread),
                (.095*reach,.031,z+spread),(.088*reach,.041,z+spread)],
                [r*1.14,r*1.08,r*.93,r,r*.86,r*.80,r*.70])
            oval(f'Support knuckle leather {i}',(.039*reach,-.014,z+spread*.3),
                 (.010,.002,r*.72),leather)
            oval(f'Support flex stitching {i}',(.066*reach,-.019,z+spread*.7),
                 (.0014,.0015,r*.74),stitch)
        curled_digit('Support opposed thumb',[
            (.005,.010,-.012),(-.006,.030,-.029),
            (.015,.048,-.047),(.044,.054,-.054)],
            [.019,.016,.0125,.010],thumb=True)
    else:
        oval('Thumb web',(mirror*.023,.002,-.029),(.017,.014,.027),glove)
        for i in range(4):
            # Index is next to the thumb on BOTH hands. Stagger MCP/PIP joints,
            # narrow the little finger, and wrap the distal phalanx under the grip.
            x=mirror*(1.5-i)*.017
            length=[.046,.055,.050,.037][i]
            base=[-.044,-.048,-.045,-.038][i]
            radius=[.009,.0095,.0088,.0075][i]
            curled_digit(f'Curled finger {i}',[(x,.008,base),
                (x,.016,base-.016),(x,.010,base-length*.77),
                (x,-.009,base-length),(x,-.026,base-length*.83),
                (x,-.029,base-length*.65)],
                [radius,radius*.98,radius*.95,radius*.90,radius*.82,radius*.72])
            oval(f'Individual knuckle pad {i}',(x,.024,base-.014),
                 (radius*.82,.003,radius*1.15),leather)
            oval(f'Finger flex seam {i}',(x,.017,base-length*.70),
                 (radius*.78,.0015,.0012),stitch)
        # Lay the thumb along the grip side. The old returning endpoint made
        # an open C-shaped loop above the palm after the firing-hand rotation.
        curled_digit('Opposed thumb',[(mirror*.024,.003,-.016),(mirror*.043,-.003,-.026),
            (mirror*.050,-.014,-.040),(mirror*.050,-.025,-.055)],
            [.014,.0125,.0105,.008],thumb=True)

    # Fuse the overlapping anatomical volumes before skinning. Joining alone
    # leaves the palm/thumb intersections as sharp internal surface seams.
    from mathutils.kdtree import KDTree
    hand_parts=[o for o in bpy.context.scene.objects
                if o not in before_hand and o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in hand_parts:
        bpy.context.view_layer.objects.active=obj
        # Bake tailoring in rest space before union: discarding SUBSURF here
        # preserved the coarse palm rings despite a very dense voxel surface.
        for modifier in list(obj.modifiers):
            if modifier.type=='ARMATURE':
                obj.modifiers.remove(modifier)
            else:
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        if obj != palm:
            # Digit objects include local translations; evaluate the shared
            # authored-frame map in world space before joining/remeshing.
            world = obj.matrix_world.copy()
            inverse = world.inverted()
            for vertex in obj.data.vertices:
                vertex.co = inverse @ grasp_point(world @ vertex.co)
            obj.data.update()
        obj.select_set(True)
    bpy.context.view_layer.objects.active=palm
    bpy.ops.object.join()
    hand=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    source_materials=[p.material_index for p in hand.data.polygons]
    nearest=KDTree(len(source_materials))
    for polygon in hand.data.polygons:
        nearest.insert(polygon.center,polygon.index)
    nearest.balance()
    hand.vertex_groups.clear()
    union=hand.modifiers.new('Continuous palm thumb and finger roots','REMESH')
    union.mode='VOXEL'
    union.voxel_size=.0012
    union.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=union.name)
    soften=hand.modifiers.new('Relax anatomical junctions','SMOOTH')
    soften.factor=.8
    soften.iterations=2
    bpy.ops.object.modifier_apply(modifier=soften.name)
    for polygon in hand.data.polygons:
        polygon.material_index=source_materials[nearest.find(polygon.center)[1]]
        polygon.use_smooth=True
    # Keep the fused silhouette without exporting hundreds of thousands of
    # triangles for two small hands. Protect material seams during collapse.
    simplify=hand.modifiers.new('Glove runtime surface budget','DECIMATE')
    simplify.ratio=.35
    simplify.delimit={'MATERIAL'}
    bpy.ops.object.modifier_apply(modifier=simplify.name)
    # Voxel union followed by edge collapse can leave duplicate triangles.
    # Remove them before generating UVs or joining the skinned meshes.
    repaired=hand.data.validate(verbose=True)
    hand.data.update()
    assert not hand.data.validate(), 'Invalid glove topology after cleanup'
    print(f'GLOVE_TOPOLOGY_PASS side={side} repaired={repaired}')
    # Remeshing removes the old overlapping UV islands. Generate a fresh atlas
    # so exported textile normals retain finite UVs on the new junctions.
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Smart-project packs islands to fill a square, irrespective of their real
    # size. Restore a common 12 cm textile repeat for every disconnected island
    # so finger webs and the palm show the same fibre scale after remeshing.
    uv_data=hand.data.uv_layers.active.data
    parents=list(range(len(hand.data.polygons)))
    def island_root(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]]; i=parents[i]
        return i
    owners={}
    for polygon in hand.data.polygons:
        for li in polygon.loop_indices:
            key=(hand.data.loops[li].vertex_index,
                 tuple(round(value,6) for value in uv_data[li].uv))
            if key in owners:
                parents[island_root(polygon.index)]=island_root(owners[key])
            else: owners[key]=polygon.index
    islands={}
    for polygon in hand.data.polygons:
        islands.setdefault(island_root(polygon.index),[]).append(polygon)
    for polygons in islands.values():
        area=sum(p.area for p in polygons)
        uv_area=0.
        loops=[li for p in polygons for li in p.loop_indices]
        for polygon in polygons:
            points=[uv_data[li].uv.copy() for li in polygon.loop_indices]
            uv_area+=abs(sum(a.x*b.y-a.y*b.x for a,b in
                            zip(points,points[1:]+points[:1])))*.5
        assert area>0 and uv_area>1e-12, 'Collapsed glove UV island'
        scale=math.sqrt(area/uv_area)/.12
        center=sum((uv_data[li].uv.copy() for li in loops),Vector((0,0)))/len(loops)
        for li in loops:
            uv_data[li].uv=center+(uv_data[li].uv-center)*scale
    print(f'GLOVE_TEXEL_SCALE_PASS side={side} islands={len(islands)} repeat_m=0.12')
    hand.name=f'Continuous glove.{side}'
    # Thin sewn dorsal panels follow the finished anatomy. Projecting onto the
    # union avoids floating ellipsoids and preserves a soft, articulated back.
    dorsal = -1 if side == 'L' else 1
    for panel_index, center_x in enumerate((-.008, .009)):
        vertices, faces, uvs = [], [], []
        rings, segments = 5, 32
        samples = [(0., 0.)] + [
            (r/rings*math.cos(math.tau*i/segments),
             r/rings*math.sin(math.tau*i/segments))
            for r in range(1, rings+1) for i in range(segments)]
        for u, w in samples:
            origin = end + v(center_x+u*.006 + (.006 if side == 'L' else 0),
                             dorsal*.12, -.021+w*.023)
            # Project the panel onto the final grasp. These rays keep authored
            # Z fixed, so the grip map is affine along each complete ray.
            ray_end = grasp_point(origin + v(0,-dorsal,0))
            origin = grasp_point(origin)
            direction = (ray_end-origin).normalized()
            hit, position, normal, _ = hand.ray_cast(origin, direction)
            if not hit:
                raise RuntimeError(f'Dorsal panel missed glove: {side} {u} {w}')
            lift = .0002 + .0005*(1-min(1., math.hypot(u,w)))
            vertices.append(position+normal*lift)
            uvs.append(((u+1)*.5,(w+1)*.5))
        for i in range(segments):
            faces.append((0,1+i,1+(i+1)%segments))
        for r in range(rings-1):
            a, b = 1+r*segments, 1+(r+1)*segments
            for i in range(segments):
                j = (i+1)%segments
                faces.append((a+i,b+i,b+j,a+j))
        mesh = bpy.data.meshes.new(f'Conforming glove panel {side} {panel_index}')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        layer = mesh.uv_layers.new(name='UVMap')
        for polygon in mesh.polygons:
            # Match the outside surface orientation in Blender coordinates.
            if polygon.normal.dot(-direction) < 0:
                polygon.flip()
            polygon.use_smooth = True
            for loop in polygon.loop_indices:
                layer.data[loop].uv = uvs[mesh.loops[loop].vertex_index]
        panel = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.collection.objects.link(panel)
        skin(panel, f'Hand.{side}', leather)
    skin(hand,f'Hand.{side}',glove)
    # Union clears source groups; assign the shared wrist field only after
    # remeshing and the firing-hand grasp transform have reached final space.
    for part in list(bpy.context.scene.objects):
        if part not in before_hand and part.type == 'MESH':
            blend_wrist(part, side)
    print(f'GLOVE_UNION_PASS side={side} source_parts={len(hand_parts)} faces={len(hand.data.polygons)} voxel_m=0.0012')

bpy.ops.object.select_all(action='DESELECT')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for obj in meshes:
    # Blender joins UV layers by name. A separate finger layer would become
    # TEXCOORD_1 while the glTF material samples TEXCOORD_0 (all-zero fingers).
    if obj.data.uv_layers:
        obj.data.uv_layers[0].name = 'UVMap'
    obj.select_set(True)
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
            shoulder, elbow, wrist = f'Shoulder.{side}', f'Elbow.{side}', f'Wrist.{side}'
            points[shoulder], points[elbow] = solve_elbow(
                rest[shoulder], points[wrist], rest[elbow],
                (rest[elbow]-rest[shoulder]).length, (rest[wrist]-rest[elbow]).length)
        for name,start,end,parent in bones:
            pose=rig.pose.bones[name]
            old=(rest[end]-rest[start]).normalized()
            new=(points[end]-points[start]).normalized()
            orientation=old.rotation_difference(new) @ pose.bone.matrix_local.to_quaternion()
            pose.matrix=Matrix.LocRotScale(points[start],orientation,Vector((1,1,1)))
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
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/first_person.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'client/assets/first_person.glb'),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_skins=True)
print('VIEWMODEL_ASSET_PASS bones=7 clips=Hold,Reload,Throw,Heal skinned_mesh=1')
