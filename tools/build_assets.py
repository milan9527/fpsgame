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
receiver_alloy = material('Receiver / anodized aluminium', (.021, .024, .020), .28)
receiver_edge = material('Receiver edge / satin anodized aluminium', (.043, .047, .039), .55)
guard_alloy = material('Handguard / muted bronze hard anodizing', (.095, .083, .062), .72)
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
# Rounded forging shoulders break up the tall rectangular receiver wall.
# Keep the top rail height and attachment frame unchanged.
section = [(-.034,-.034),(-.025,-.043),(.025,-.043),
           (.034,-.034),(.039,-.021),(.041,-.004),
           (.038,.010),(.029,.026),(.022,.043),
           (.018,.055),(-.018,.055),(-.022,.043),
           (-.029,.026),(-.038,.010),(-.041,-.004),
           (-.039,-.021)]
section_count = len(section)
# A forged buffer tower transitions into the receiver over several shoulders.
# The previous two-section extrusion left a flat rear wall facing the camera.
receiver_stations = [
    (-.177, .49, .46, .008),
    (-.160, .54, .56, .005),
    (-.127, .76, .83, .002),
    (-.090, .84, .96, .000),
    (-.055, .94, 1.00, .000),
    (.065, .94, 1.00, .000),
    (.120, .90, 1.00, .000),
    (.128, .86, .94, .000),
]
# Stage104: 60 mm forging, with attachment faces following the slimmer shell.
vertices = [(x * width * .78, y, z * height + lift)
            for y, width, height, lift in receiver_stations for x, z in section]
faces = [(j*section_count+i, j*section_count+(i+1)%section_count,
          (j+1)*section_count+(i+1)%section_count, (j+1)*section_count+i)
         for j in range(len(receiver_stations)-1) for i in range(section_count)]
faces += [tuple(reversed(range(section_count))),
          tuple(range((len(receiver_stations)-1)*section_count,
                      len(receiver_stations)*section_count))]
receiver_mesh = bpy.data.meshes.new('Forged receiver profile')
receiver_mesh.from_pydata(vertices, [], faces)
receiver = bpy.data.objects.new('Upper receiver', receiver_mesh)
bpy.context.collection.objects.link(receiver)
receiver.data.materials.append(receiver_alloy)
receiver.data.materials.append(receiver_edge)
# The sloped forging shoulders use a satin finish; retain darker vertical
# walls rather than giving the entire extrusion the same broad highlight.
for polygon in receiver.data.polygons:
    if polygon.index < (len(receiver_stations)-1)*section_count:
        polygon.material_index = 1 if polygon.index % section_count in (7, 11) else 0
bpy.context.view_layer.objects.active = receiver
receiver.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
# Recess the right-hand ejection port instead of painting a rectangle on a cube.
bpy.ops.mesh.primitive_cube_add(size=1, location=(0.036, 0.015, 0.008))
cutter = bpy.context.object
cutter.dimensions = (0.022, 0.10, 0.036)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.context.view_layer.objects.active = receiver
cut = receiver.modifiers.new('Ejection recess', 'BOOLEAN')
cut.operation = 'DIFFERENCE'
cut.object = cutter
bpy.ops.object.modifier_apply(modifier=cut.name)
bpy.data.objects.remove(cutter, do_unlink=True)
edge = receiver.modifiers.new('Forged edges', 'BEVEL')
edge.width = 0.0022
edge.segments = 3
edge.material = 1
receiver.modifiers.new('Receiver normals', 'WEIGHTED_NORMAL')
bolt_metal = material('Bolt / brushed steel', (0.085, 0.09, 0.095), 0.85)
box('Visible bolt', (0.026, 0.015, 0.008), (0.004, 0.085, 0.027), bolt_metal, 0.002)
def cylinder(name, at, radius, depth, mat, axis='Y'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=at)
    obj=bpy.context.object;obj.name=name
    if axis=='Y': obj.rotation_euler.x=math.pi/2
    elif axis=='X': obj.rotation_euler.y=math.pi/2
    obj.data.materials.append(mat)
    bevel=obj.modifiers.new('Turned edge', 'BEVEL');bevel.width=0.001;bevel.segments=2
    obj.modifiers.new('Machined normals','WEIGHTED_NORMAL')
    return obj

def side_profile(name, outline, width, mat):
    """Extrude a manufactured silhouette in the longitudinal Y/Z plane."""
    n = len(outline)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([(x, y, z) for x in [-width / 2, width / 2]
                     for y, z in outline], [],
                    [tuple(reversed(range(n))), tuple(range(n, n * 2))]
                    + [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bevel = obj.modifiers.new('Rounded mould edges', 'BEVEL')
    bevel.width = .003
    bevel.segments = 3
    obj.modifiers.new('Profile normals', 'WEIGHTED_NORMAL')
    return obj

def contoured_stock(name, stations, mat):
    """Loft rounded cross sections: (longitudinal position, width, bottom, top)."""
    vertices, faces = [], []
    segments = 32
    for y, width, bottom, top in stations:
        for j in range(segments):
            a = math.tau * j / segments
            # Broad but crowned sides with a rolled comb, not an extruded slab.
            x = math.copysign(abs(math.cos(a)) ** .78, math.cos(a)) * width / 2
            z = (top + bottom) / 2 + math.copysign(
                abs(math.sin(a)) ** .78, math.sin(a)) * (top - bottom) / 2
            vertices.append((x, y, z))
    faces.append(tuple(reversed(range(segments))))
    for ring in range(len(stations) - 1):
        for j in range(segments):
            k = (j + 1) % segments
            faces.append((ring*segments+j, ring*segments+k,
                          (ring+1)*segments+k, (ring+1)*segments+j))
    faces.append(tuple(range((len(stations)-1)*segments, len(stations)*segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
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
        polygon.use_smooth = len(polygon.vertices) == 4
    bevel = obj.modifiers.new('Mould cut edge', 'BEVEL')
    bevel.width = .0015
    bevel.segments = 3
    return obj

def shoulder_pad(y, center_z, width=.056, height=.126):
    """Rubber pad with a rolled perimeter and moulded traction ribs."""
    rubber = material('Shoulder pad / charcoal rubber', (.009, .011, .010))
    rubber.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .96
    vertices, faces = [], []
    segments = 48
    # Longitudinal rings roll the edge toward the shoulder, avoiding a slab face.
    for offset, scale in [(0, .86), (-.004, 1), (-.011, 1), (-.017, .88)]:
        for j in range(segments):
            a = math.tau*j/segments
            x = math.copysign(abs(math.cos(a))**.65, math.cos(a))*width*.5*scale
            z = math.copysign(abs(math.sin(a))**.65, math.sin(a))*height*.5*scale
            vertices.append((x, y+offset, center_z+z))
    faces.append(tuple(reversed(range(segments))))
    for ring in range(3):
        for j in range(segments):
            k = (j+1)%segments
            faces.append((ring*segments+j, ring*segments+k,
                          (ring+1)*segments+k, (ring+1)*segments+j))
    faces.append(tuple(range(3*segments, 4*segments)))
    mesh = bpy.data.meshes.new('Crowned rubber')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    pad = bpy.data.objects.new('Butt plate', mesh)
    bpy.context.collection.objects.link(pad)
    pad.data.materials.append(rubber)
    for polygon in mesh.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    parts = [pad]
    for i in range(-5, 6):
        z = i*.010
        span = width*.80*(1-.24*(abs(i)/5)**3)
        parts.append(box('Pad traction rib', (0,y-.018,center_z+z),
                         (span,.003,.0035),rubber,.0015))
    # Apply finishes and retain the existing four-mesh weapon contract.
    for obj in parts:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = pad
    bpy.ops.object.join()
    return pad

def recess(obj, location, dimensions, radius=0):
    cutter = box('Temporary milling tool', location, dimensions, steel, 0)
    if radius:
        # A rounded milling bit leaves radiused slot ends, not square holes.
        bevel = cutter.modifiers.new('Milling bit radius', 'BEVEL')
        bevel.width = radius
        bevel.segments = 5
        bpy.context.view_layer.objects.active = cutter
        bpy.ops.object.modifier_apply(modifier=bevel.name)
    bpy.context.view_layer.objects.active = obj
    cut = obj.modifiers.new('Milled opening', 'BOOLEAN')
    cut.operation = 'DIFFERENCE'
    cut.object = cutter
    # Apply before the edge finish so cut rims receive the same bevel.
    bpy.ops.object.modifier_move_up(modifier=cut.name)
    bpy.ops.object.modifier_move_up(modifier=cut.name)
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

# Separate the raised magazine well from the shallow fire-control housing.
# The underside now follows the trigger opening instead of a rectangular slab.
lower = side_profile('Forged lower receiver', [
    (-.13,-.040),(.100,-.040),(.105,-.066),(.083,-.104),
    (.063,-.111),(-.012,-.105),(-.023,-.079),
    (-.091,-.079),(-.118,-.092),(-.130,-.074)], .054, receiver_alloy)
for side in [-1, 1]:
    # Shallow joint channel preserves the structural core and catches a thin
    # shadow between the upper forging and the fire-control housing.
    recess(lower, (side*.027,-.010,-.041), (.008,.202,.003), .0008)
    recess(lower, (side*.029,.040,-.069), (.010,.070,.029), .005)
    cylinder('Lower takedown pin', (side*.027,-.105,-.058),
             .0045,.003,bolt_metal,'X')
cylinder('Barrel', (0, 0.36, 0.015), 0.018, 0.38, steel)
for y in [0.32, 0.44, 0.51]: cylinder('Barrel collar',(0,y,0.015),0.022,0.015,steel)
# Recessed-looking side plates, charging handle and fasteners stay clear of the sight line.
for side in [-1,1]:
    if side < 0:
        # One shaped forging pocket replaces the two rectangular slots.
        # Its diagonal ends follow the buffer tower and barrel extension,
        # leaving a continuous structural rim and a real recessed floor.
        cutter = side_profile('Forging relief tool', [
            (-.075,-.014),(-.058,-.024),(.063,-.024),
            (.087,-.006),(.087,.016),(.073,.024),
            (-.046,.024),(-.075,.005)], .018, receiver_alloy)
        cutter.location.x = -.034
        bpy.context.view_layer.objects.active = cutter
        bpy.ops.object.modifier_apply(modifier='Rounded mould edges')
        bpy.context.view_layer.objects.active = receiver
        cut = receiver.modifiers.new('Contoured forging relief', 'BOOLEAN')
        cut.operation = 'DIFFERENCE'
        cut.object = cutter
        bpy.ops.object.modifier_move_up(modifier=cut.name)
        bpy.ops.object.modifier_move_up(modifier=cut.name)
        bpy.ops.object.modifier_apply(modifier=cut.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
        for y in [-.094,.079]:
            cylinder('Flush receiver cross pin',(-.029,y,-.009),
                     .003,.0015,steel,'X')
    for y in [-0.10,0.03]:
        cylinder('Receiver pin',(side*(0.026 if y < 0 else 0.029),y,-0.008),
                 .0045,.002,steel,'X')
box('Charging handle stem',(0,-0.134,0.042),(0.016,0.059,0.007),steel,0.0015)
for side in [-1, 1]:
    # Forged hooked paddles, with a longer support-side release. The thin
    # swept neck and hooked end replace the conspicuous straight crossbar.
    reach = .039 if side == -1 else .030
    outline = [(side*.007,-.154),(side*.018,-.156),
               (side*reach,-.163),(side*(reach+.001),-.172),
               (side*(reach-.005),-.174),(side*(reach-.007),-.168),
               (side*.017,-.163),(side*.007,-.161)]
    if side == 1: outline.reverse()
    count = len(outline)
    vertices = [(x,y,z) for z in [.037,.044] for x,y in outline]
    faces = [tuple(reversed(range(count))),tuple(range(count,2*count))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    mesh = bpy.data.meshes.new('Forged latch profile')
    mesh.from_pydata(vertices,[],faces);mesh.update()
    latch = bpy.data.objects.new('Charging handle hooked paddle',mesh)
    bpy.context.collection.objects.link(latch)
    latch.data.materials.append(steel)
    bevel=latch.modifiers.new('Forged edge radius','BEVEL')
    bevel.width=.001;bevel.segments=3
    latch.modifiers.new('Latch corner normals','WEIGHTED_NORMAL')
    for i in range(3):
        box('Latch dark grip ridges',(side*(reach-.004+i*.0015),-.172,.0405),
            (.0007,.0015,.004),steel,.0003)
cylinder('Selector spindle', (-0.029, -0.081, -0.065), 0.009, 0.006, bolt_metal, 'X')
box('Selector lever', (-0.034, -0.063, -0.067), (0.01, 0.039, 0.009), steel, 0.002)
for side in [-1, 1]:
    box('Receiver reinforcement', (side * 0.017, 0.029, 0.046),
        (0.006, 0.23, 0.009), steel, 0.002)
box('Trigger guard lower',(0,-0.055,-0.125),(0.022,0.074,0.013),steel,0.003)
box('Trigger guard front',(0,-0.016,-0.10),(0.022,0.013,0.055),steel,0.003)
# Free-float extrusion: broad diagonal shoulders and a tapered nose replace
# the rectangular slab. The barrel and support-hand anchors remain unchanged.
guard_section = [(-.022,-.037),(.022,-.037),(.034,-.029),
                 (.0415,-.012),(.0415,.017),(.033,.032),
                 (.018,.044),(-.018,.044),(-.033,.032),
                 (-.0415,.017),(-.0415,-.012),(-.034,-.029)]
guard_stations = [(.130,.91),(.150,1.0),(.283,.94),(.323,.80)]
guard_count = len(guard_section)
mesh = bpy.data.meshes.new('Octagonal free float extrusion')
mesh.from_pydata([(x*scale,y,z*scale) for y,scale in guard_stations
                 for x,z in guard_section], [],
                [tuple(reversed(range(guard_count))),
                 tuple(range(3*guard_count,4*guard_count))]
                + [(r*guard_count+j,r*guard_count+(j+1)%guard_count,
                    (r+1)*guard_count+(j+1)%guard_count,(r+1)*guard_count+j)
                   for r in range(3) for j in range(guard_count)])
mesh.update()
handguard = bpy.data.objects.new('Hand guard',mesh)
bpy.context.collection.objects.link(handguard)
bpy.ops.object.select_all(action='DESELECT')
handguard.select_set(True)
bpy.context.view_layer.objects.active = handguard
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
handguard.data.materials.append(guard_alloy)
handguard.data.materials.append(guard_alloy)
edge = handguard.modifiers.new('Extrusion edge finish','BEVEL')
edge.width=.0014
edge.segments=3
edge.material=1
handguard.modifiers.new('Extrusion normals','WEIGHTED_NORMAL')
recess(handguard, (0,.23,.004), (.059,.24,.048))
# A separate clamping shoe gives the extrusion a mechanical attachment.
# The upper receiver ends behind it, leaving the first cooling port open.
for side in [-1, 1]:
    shoe = box('Handguard rear clamp', (side*.039,.140,-.012),
               (.009,.023,.042), receiver_alloy, .003)
    recess(shoe, (side*.044,.140,-.012), (.004,.012,.022), .003)
    for z in [-.021,-.003]:
        screw = cylinder('Recessed clamp screw', (side*.043,.140,z),
                         .0035,.002,bolt_metal,'X')
        recess(screw, (side*.044,.140,z), (.002,.003,.001))
for y in [.165,.202,.239,.276]:
    recess(handguard, (0,y,.010), (.10,.027,.018), .006)
    recess(handguard, (0,y,-.031), (.023,.027,.023), .005)
# Separate upper cooling windows expose the barrel below the narrow top rail.
for y in [.178,.223,.268]:
    for side in [-1,1]:
        recess(handguard, (side*.025,y,.034), (.014,.030,.034), .004)
# Low polymer contact strips reveal the different metal/polymer responses;
# leave the milled ventilation slots exposed above them.
for side in [-1,1]:
    strip=box('Handguard grip insert',(side*.036,.225,-.021),
              (.005,.126,.017),polymer,.002)
    strip.rotation_euler.y=side*-.55
    for y in [.173,.189,.205,.221,.237,.253,.269]:
        rib=box('Grip insert traction rib',(side*.039,y,-.021),
                (.003,.004,.012),polymer,.0008)
        rib.rotation_euler.y=side*-.55
brake = cylinder('Muzzle brake', (0,.55,.015), .027, .065, steel)
recess(brake, (0,.575,.015), (.026,.04,.026))
for y in [.535,.555]:
    recess(brake, (0,y,.015), (.07,.009,.014))
# A curved stack with crowned, rolled side walls. Keep the attachment and
# extraction node at the authored origin so the existing reload stays valid.
mag_shell = material('Magazine / moulded graphite', (.055, .059, .047))
mag_parts = []
mag_rings = []
mag_segments = 40
for row in range(21):
    t = row / 20
    z = -.095 - .185 * t
    center = .0105 + .044 * t * t
    half_depth = .0485 - .006 * t
    half_width = .030 - .002 * t
    mag_rings.extend([
        (math.copysign(abs(math.cos(a)) ** .48, math.cos(a)) * half_width,
         center + math.copysign(abs(math.sin(a)) ** .48, math.sin(a)) * half_depth, z)
        for a in [math.tau * j / mag_segments for j in range(mag_segments)]])
mag_faces = [tuple(reversed(range(mag_segments))),
             tuple(range(20 * mag_segments, 21 * mag_segments))]
mag_faces += [(r*mag_segments+j, r*mag_segments+(j+1)%mag_segments,
               (r+1)*mag_segments+(j+1)%mag_segments, (r+1)*mag_segments+j)
              for r in range(20) for j in range(mag_segments)]
mesh = bpy.data.meshes.new('Curved magazine shell')
mesh.from_pydata(mag_rings, [], [tuple(reversed(f)) for f in mag_faces])
mesh.update()
magazine = bpy.data.objects.new('Magazine', mesh)
bpy.context.collection.objects.link(magazine)
magazine.data.materials.append(mag_shell)
for face in mesh.polygons:
    face.use_smooth = len(face.vertices) == 4
mag_parts.append(magazine)
# Shallow moulded reinforcing rails follow the curve instead of floating
# straight strips; the flat baseplate closes the shell with a rolled rim.
for side in [-1, 1]:
    for offset in [-.025, 0, .025]:
        curve = bpy.data.curves.new('Magazine moulded rail', 'CURVE')
        curve.dimensions = '3D'
        curve.bevel_depth = .0014
        curve.bevel_resolution = 3
        spline = curve.splines.new('POLY')
        spline.points.add(16)
        for j, point in enumerate(spline.points):
            t = .24 + .68 * j / 16
            point.co = (side * (.030 - .002*t - .0005),
                        .0105 + .044*t*t + offset, -.095-.185*t, 1)
        rail = bpy.data.objects.new('Magazine rail', curve)
        bpy.context.collection.objects.link(rail)
        curve.materials.append(mag_shell)
        bpy.ops.object.select_all(action='DESELECT')
        rail.select_set(True)
        bpy.context.view_layer.objects.active = rail
        bpy.ops.object.convert(target='MESH')
        mag_parts.append(bpy.context.object)
mag_parts.append(box('Magazine floorplate', (0, .0545, -.281),
                     (.060, .091, .012), polymer, .004))
mag_parts.append(box('Magazine base latch', (0, .033, -.287),
                     (.020, .025, .002), mag_shell, .001))
# All details must belong to the one MeshInstance animated by first_person.gd.
for part in mag_parts:
    bpy.context.view_layer.objects.active = part
    for modifier in list(part.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action='DESELECT')
for part in mag_parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = magazine
bpy.ops.object.join()
# An oval palm swell and curved backstrap replace the flat extruded grip.
# The attachment and trigger-hand anchor remain fixed.
grip_rings = [(-.080,-.126,.021,.022),(-.095,-.131,.022,.025),
              (-.121,-.140,.023,.026),(-.150,-.149,.022,.026),
              (-.176,-.155,.021,.025),(-.189,-.157,.020,.023),
              (-.195,-.157,.017,.020)]
segments = 32
verts = [(math.cos(i*math.tau/segments)*rx,
          y+math.sin(i*math.tau/segments)*ry,z)
         for z,y,rx,ry in grip_rings for i in range(segments)]
faces = [tuple(reversed(range(segments))),
         tuple(range((len(grip_rings)-1)*segments,len(grip_rings)*segments))]
faces += [(r*segments+i,r*segments+(i+1)%segments,
           (r+1)*segments+(i+1)%segments,(r+1)*segments+i)
          for r in range(len(grip_rings)-1) for i in range(segments)]
mesh = bpy.data.meshes.new('Palm swell and curved backstrap')
# Rings run from the grip attachment downward: reverse the winding.
mesh.from_pydata(verts,[],[tuple(reversed(face)) for face in faces]);mesh.update()
grip = bpy.data.objects.new('Pistol grip',mesh)
bpy.context.collection.objects.link(grip)
grip.data.materials.append(polymer)
# Moulded side-panel finishes follow the existing palm swell.
# Reload exposes these faces beyond the trigger hand.
grip_panel = material('Grip / stippled elastomer', (.022,.025,.021))
grip_panel.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.92
grip.data.materials.append(grip_panel)
for polygon in mesh.polygons:
    if len(polygon.vertices)==4:
        center = sum((mesh.vertices[i].co for i in polygon.vertices),
                     __import__('mathutils').Vector()) / 4
        if -.186 < center.z < -.105 and abs(center.x) > .016:
            polygon.material_index=1
for polygon in mesh.polygons: polygon.use_smooth = len(polygon.vertices)==4
bevel = grip.modifiers.new('Moulded grip heel','BEVEL')
bevel.width=.0015;bevel.segments=3
cylinder('Stock buffer tube', (0,-.247,.008), .022, .20, steel)
stock = side_profile('Butt stock', [
    (-.202,.024),(-.365,.024),(-.390,.010),(-.390,-.096),
    (-.376,-.096),(-.224,-.034),(-.202,-.022)], .046, polymer)
# A tapered through-opening leaves a buffer sleeve, diagonal lower brace and
# rear upright. Cut before beveling so the internal edges receive the same
# moulded finish as the external silhouette.
opening = side_profile('Stock opening cutter', [
    (-.240,-.005),(-.374,-.005),(-.374,-.079),(-.240,-.023)], .12, polymer)
for modifier in list(opening.modifiers):
    opening.modifiers.remove(modifier)
bpy.context.view_layer.objects.active = stock
cut = stock.modifiers.new('Open skeletal stock', 'BOOLEAN')
cut.operation = 'DIFFERENCE'
cut.object = opening
bpy.ops.object.modifier_move_up(modifier=cut.name)
bpy.ops.object.modifier_move_up(modifier=cut.name)
bpy.ops.object.modifier_apply(modifier=cut.name)
bpy.data.objects.remove(opening, do_unlink=True)
# A separate moulded cheek saddle gives the camera-facing stock a stepped
# shoulder and a seam, instead of one uninterrupted smooth inflated surface.
cheek_polymer = material('Stock / moulded olive nylon', (.065,.071,.052))
cheek_polymer.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .76
cheek = contoured_stock('Stock cheek saddle', [
    (-.224,.026,.018,.024),(-.244,.032,.017,.027),
    (-.278,.034,.017,.028),(-.328,.033,.017,.026),
    (-.354,.025,.016,.022)], cheek_polymer)
for side in [-1, 1]:
    recess(cheek, (side*.020,-.299,.019), (.008,.072,.003))
# A recessed elastomer cheek contact surface breaks up the large camera-facing
# comb. Rolled ends and shallow transverse mould grooves avoid a floating plate.
comb_rubber = material('Cheek contact / textured elastomer', (.016,.019,.016))
comb_rubber.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .94
comb = contoured_stock('Inset cheek contact', [
    (-.250,.014,.025,.027),(-.266,.023,.026,.029),
    (-.309,.024,.025,.029),(-.335,.016,.023,.026)], comb_rubber)
# Fine stipple, rather than deep transverse trenches, belongs on the contact
# surface. The tapered moulding below remains visible around the rubber insert.
# Functional hardware gives the open lower stock a recognisable silhouette.
side_profile('Stock adjustment paddle', [
    (-.246,-.043),(-.272,-.051),(-.323,-.074),
    (-.329,-.068),(-.281,-.042),(-.249,-.035)], .032, polymer)
for side in [-1, 1]:
    cylinder('Stock latch pivot', (side*.024,-.251,-.026), .006, .004,
             steel, 'X')
    cylinder('Stock sling socket rim', (side*.024,-.380,-.071), .007,
             .004, steel, 'X')
    cylinder('Stock sling socket inset', (side*.027,-.380,-.071), .0045,
             .001, comb_rubber, 'X')
# Join into the existing stock node: reload/obstruction code keeps its mesh
# contract and the saddle follows exactly the same weapon transforms.
for part in [stock, cheek, comb]:
    bpy.context.view_layer.objects.active = part
    for modifier in list(part.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action='DESELECT')
stock.select_set(True)
cheek.select_set(True)
comb.select_set(True)
bpy.context.view_layer.objects.active = stock
bpy.ops.object.join()
shoulder_pad(-.390, -.040)
# Open saddle mount and rolled reflex shell. Preserve the sight datum and
# rail interface; the riser opening goes along Y, so it is visible from ADS.
anodized = material('Optic / bead blasted aluminium', (.047,.052,.048), .72)
anodized.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .51
optic_lip = material('Optic / satin machined rim', (.073,.080,.073), .75)
optic_seal = material('Optic / recessed rubber gasket', (.012,.014,.012))
box('Optic saddle base',(0,-.014,.071),(.048,.056,.009),anodized,.002)
for side in [-1,1]:
    # Separate tapered struts leave a real central window, not a painted inset.
    strut = side_profile('Tapered saddle strut',[
        (-.038,.075),(.010,.075),(.003,.100),(-.027,.100)],.008,anodized)
    strut.location.x = side*.016
    box('Separate dovetail clamp',(side*.024,-.014,.066),
        (.007,.059,.011),steel,.0015)
    for y in [-.035,.006]:
        cylinder('Recessed clamp washer',(side*.029,y,.068),.0045,.002,polymer,'X')
        cylinder('Clamp crossbolt',(side*.0305,y,.068),.0028,.003,bolt_metal,'X')
box('Optic emitter housing',(0,-.010,.098),(.043,.034,.008),anodized,.003)
# Rounded corners instead of four large planar chamfers. The front shell flares
# slightly and a separate recessed dark gasket gives the aperture wall depth.
def optic_contour(width, height, radius):
    points=[]
    for cx,cz,angle in [(width-radius,height-radius,0),
                       (-width+radius,height-radius,90),
                       (-width+radius,-height+radius,180),
                       (width-radius,-height+radius,270)]:
        for step in range(9):
            a=math.radians(angle+step*90/8)
            x=cx+radius*math.cos(a)
            z=cz+radius*math.sin(a)
            # Narrow the upper shoulders into a protective arched hood.
            # Apply the same mapping to all nested contours so the gasket
            # and machined rim follow the shell, leaving the sight datum clear.
            shoulder=max(0.,z/height)
            x*=1-.24*shoulder**1.4
            z+=height*.09*shoulder*(1-(x/width)**2)
            points.append((x,z))
    return points

def optic_ring(name, outer, inner, rear, front, mat, flare=1.0):
    n=len(outer)
    verts=[(x*scale,y,z*scale+.13)
           for y,scale in [(rear,1.0),(front,flare)]
           for loop in [outer,inner] for x,z in loop]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),
                  (j,i,n+i,n+j),(2*n+i,2*n+j,3*n+j,3*n+i)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    edge=obj.modifiers.new('Fine rolled edge','BEVEL');edge.width=.00045;edge.segments=3
    obj.modifiers.new('Optic normals','WEIGHTED_NORMAL')
    return obj
outer=optic_contour(.033,.030,.010)
inner=optic_contour(.0305,.0275,.008)
optic_ring('Chamfered optic hood',outer,inner,-.027,.008,anodized,1.025)
optic_ring('Satin rear rim',outer,optic_contour(.032,.029,.009),-.028,-.025,optic_lip)
optic_ring('Recessed aperture gasket',inner,optic_contour(.0295,.0265,.007),-.023,-.018,optic_seal)
# Low windage drum and opposite battery compartment have distinct collars,
# gasket seams, inset coin slots and restrained edge highlights.
for side,radius in [(1,.007),(-1,.010)]:
    z=.117 if side==1 else .119
    cylinder('Optic control collar',(side*.034,-.009,z),radius+.0015,.006,anodized,'X')
    cylinder('Optic control seal',(side*.038,-.009,z),radius,.002,optic_seal,'X')
    cap=cylinder('Optic slotted control cap',(side*.040,-.009,z),radius,.003,optic_lip,'X')
    recess(cap,(side*.042,-.009,z),(.004,radius*1.4,.0016))
    for index in range(12):
        angle=index*math.tau/12
        y=-.009+math.cos(angle)*(radius-.0008)
        height=z+math.sin(angle)*(radius-.0008)
        box('Control rim grip',(side*.040,y,height),(.003,.001,.001),anodized,.0002)
# Receiver end hardware and buffer lock ring break up the smooth rear silhouette.
for y in [-.181,-.191]:
    cylinder('Buffer lock ring', (0,y,.008), .026, .006, bolt_metal)
for side in [-1,1]:
    for y in [-.11,.075]:
        cylinder('Flush receiver screw', (side*(.024 if y < 0 else .028),y,-.019), .004, .003, bolt_metal, 'X')
# Narrow continuous dovetail with closely spaced cross slots. The old 50 mm
# teeth were wider than the receiver crown and read as a ladder in ADS.
box('Rail continuous spine', (0, .103, .055), (.017, .418, .005), steel, .0008)
for i in range(42):
    y = -.10 + i * .01
    profile = [(-.0085,.054),(.0085,.054),(.0106,.058),
               (.0106,.060),(-.0106,.060),(-.0106,.058)]
    vertices = [(x, yy, z) for yy in [y-.0024,y+.0024] for x,z in profile]
    faces = [tuple(range(6)),tuple(reversed(range(6,12)))]
    faces += [(j+6,(j+1)%6+6,(j+1)%6,j) for j in range(6)]
    mesh = bpy.data.meshes.new('Dovetail cross section')
    mesh.from_pydata(vertices, [], faces);mesh.update()
    tooth = bpy.data.objects.new('Rail_%02d' % i, mesh)
    bpy.context.collection.objects.link(tooth)
    tooth.data.materials.append(steel)
    edge = tooth.modifiers.new('Rail edge highlights','BEVEL')
    edge.width=.0004;edge.segments=2
    tooth.modifiers.new('Rail normals','WEIGHTED_NORMAL')
box('Identification plate', (-0.045, 0.019, -0.012), (0.002, 0.042, 0.010), bolt_metal, 0.001)
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

def bake_weapon_finish():
    """Exportable PBR grain: image nodes and metric UVs, no runtime noise."""
    import numpy as np
    rng = np.random.default_rng(59)
    size = 512
    grain = rng.normal(0, 1, (size, size))
    # Broad low-contrast variations plus fine bead-blast/mould grain.
    broad = rng.normal(0, 1, (32, 32)).repeat(16, 0).repeat(16, 1)
    for _ in range(20):
        broad = (broad + np.roll(broad, 1, 0) + np.roll(broad, -1, 0)
                 + np.roll(broad, 1, 1) + np.roll(broad, -1, 1)) / 5
    for mat, roughness, strength in [
        # Dark anodizing with a tighter shoulder highlight distinguishes the
        # forged receiver from the diffuse stock without painted edge stripes.
        # Effective oxide-coated finish: suppress the broad sky-coloured
        # reflection on the body, retaining a satin highlight at the shoulders.
        (receiver_alloy, .46, .014), (receiver_edge, .35, .012),
        (guard_alloy, .47, .035),
        (anodized, .51, .045),
        (polymer, .84, .065), (mag_shell, .76, .055),
        (cheek_polymer, .79, .10), (comb_rubber, .94, .16),
        (grip_panel, .92, .075),
    ]:
        bsdf = mat.node_tree.nodes['Principled BSDF']
        base = np.array(mat.diffuse_color[:3])
        # Fine anodizing follows the forged shoulder; broad mottling made
        # the small receiver read like weathered cast concrete at game scale.
        forged = mat in (receiver_alloy, receiver_edge)
        broad_colour = .025 if forged else .10
        grain_roughness = .015 if forged else .035
        broad_roughness = .012 if forged else .04
        # Image base colours are stored as sRGB; diffuse colours above are linear.
        linear = np.clip(base[None, None, :] *
                         (1 + strength * grain[:, :, None] +
                          broad_colour * broad[:, :, None]), 0, 1)
        srgb = np.where(linear <= .0031308, linear * 12.92,
                        1.055 * linear**(1/2.4) - .055)
        for suffix, rgb, socket in [
            ('colour', srgb, 'Base Color'),
            ('roughness', np.repeat(np.clip(roughness + grain[:, :, None]*grain_roughness
                                            + broad[:, :, None]*broad_roughness, .3, .96), 3, 2),
             'Roughness'),
        ]:
            image = bpy.data.images.new(mat.name + ' ' + suffix, size, size)
            if suffix == 'roughness':
                image.colorspace_settings.name = 'Non-Color'
            image.pixels.foreach_set(np.concatenate(
                [rgb, np.ones((size, size, 1))], 2).astype(np.float32).ravel())
            image.pack()
            node = mat.node_tree.nodes.new('ShaderNodeTexImage')
            node.image = image
            mat.node_tree.links.new(node.outputs['Color'], bsdf.inputs[socket])
        if forged or mat == guard_alloy or mat == grip_panel:
            # Tangent normal grain survives GLB export; millimetre-scale
            # rounded mould texture avoids the painted-flat rubber look.
            height = grain.copy()
            for _ in range(3):
                height = (height + np.roll(height,1,0) + np.roll(height,-1,0)
                          + np.roll(height,1,1) + np.roll(height,-1,1))/5
            if forged or mat == guard_alloy:
                # Fine longitudinal machining under the anodizing. The
                # low amplitude preserves clean metal at gameplay distance;
                # unlike colour speckle it responds to moving illumination.
                brushed = rng.normal(0, 1, (size, 1)).repeat(size, 1)
                for _ in range(2):
                    brushed = (brushed + np.roll(brushed,1,0)
                               + np.roll(brushed,-1,0))/3
                height = height*.10 + brushed*.12
            dx = (np.roll(height,-1,1)-np.roll(height,1,1))*.85
            dy = (np.roll(height,-1,0)-np.roll(height,1,0))*.85
            normal = np.stack([-dx,-dy,np.ones_like(dx)],2)
            normal /= np.linalg.norm(normal,axis=2,keepdims=True)
            image=bpy.data.images.new(mat.name+' tangent normal',size,size)
            image.colorspace_settings.name='Non-Color'
            image.pixels.foreach_set(np.concatenate(
                [normal*.5+.5,np.ones((size,size,1))],2).astype(np.float32).ravel())
            image.pack()
            texture=mat.node_tree.nodes.new('ShaderNodeTexImage');texture.image=image
            normal_node=mat.node_tree.nodes.new('ShaderNodeNormalMap')
            mat.node_tree.links.new(texture.outputs['Color'],normal_node.inputs['Color'])
            mat.node_tree.links.new(normal_node.outputs['Normal'],bsdf.inputs['Normal'])
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='FinishUV')
        for polygon in obj.data.polygons:
            axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
            axes = [i for i in range(3) if i != axis]
            for index in polygon.loop_indices:
                co = obj.matrix_world @ obj.data.vertices[obj.data.loops[index].vertex_index].co
                uv.data[index].uv = (co[axes[0]] / .16, co[axes[1]] / .16)

bake_weapon_finish()
bpy.ops.object.select_all(action='SELECT')
if os.environ.get('ASSET_ONLY') not in ('shotgun', 'marksman'):
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'carbine.glb'), export_format='GLB', use_selection=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'carbine.blend'))
if os.environ.get('ASSET_ONLY') == 'carbine':
    raise SystemExit(0)
exec(compile((ROOT / 'tools' / 'build_weapon_variants.py').read_text(), 'build_weapon_variants.py', 'exec'))
if os.environ.get('ASSET_ONLY') in ('weapons', 'shotgun', 'marksman'):
    raise SystemExit(0)

# The humanoid authoring script shares the material palette and mesh helpers.
exec(compile((ROOT / 'tools' / 'build_operator.py').read_text(), 'build_operator.py', 'exec'))
print('ASSETS_BUILT carbine.glb shotgun.glb marksman.glb operator.glb')

exec(compile((ROOT / 'tools' / 'build_grenade.py').read_text(), str(ROOT / 'tools' / 'build_grenade.py'), 'exec'))
exec(compile((ROOT / 'tools' / 'build_viewmodel.py').read_text(), str(ROOT / 'tools' / 'build_viewmodel.py'), 'exec'))
