"""Stage400: fuller overlapping shoots without increasing the needle budget.

Blender --background --python tools/build_branching_fir.py
No downloads. Mesh needles (no alpha cards) preserve near-view depth and shadows.
"""
import math
import random
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(113)
bpy.ops.wm.read_factory_settings(use_empty=True)
verts, faces, slots = [], [], []
normals, uv_faces = [], []


def face(points, slot, custom_normals=None, uv=None):
    start = len(verts)
    verts.extend(points)
    faces.append(tuple(range(start, start + len(points))))
    slots.append(slot)
    normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
    normals.extend(custom_normals or [normal] * len(points))
    uv_faces.append(uv or [(0, 0)] * len(points))


def limb(a, b, radius, tip):
    direction = (b - a).normalized()
    u = direction.cross(Vector((0, 1, 0))).normalized()
    v = direction.cross(u).normalized()
    sides = 14 if radius > .08 else 6
    for i in range(sides):
        x, y = i * math.tau / sides, (i + 1) * math.tau / sides
        p, q = u * math.cos(x) + v * math.sin(x), u * math.cos(y) + v * math.sin(y)
        face([a + p * radius, a + q * radius, b + q * tip, b + p * tip], 0,
             [p, q, q, p],
             [(i / sides, a.z * .65), ((i + 1) / sides, a.z * .65),
              ((i + 1) / sides, b.z * .65), (i / sides, b.z * .65)])


def spray(base, direction, size):
    """A woody shoot with radial needles, tapered into an irregular leafy tip."""
    direction.normalize()
    side = direction.cross(Vector((0, 0, 1))).normalized()
    up = direction.cross(side).normalized()
    bend = up * rng.uniform(-.16, .10) * size
    def point(t):
        return base + direction * size * t + bend * (4 * t * (1 - t))
    end = point(1)
    limb(base, point(.5), .0035, .002)
    limb(point(.5), end, .002, .0007)
    # Old 20 cm wide triangular leaves read as stacked fern fans at eye level.
    # Narrow straps surround the shoot; enough projected area must survive
    # a normal gameplay camera, otherwise thin needles turn into bare boughs.
    for i in range(56):
        # Stratification prevents accidental bare gaps along a shoot. Keep
        # real geometry so nearby branches retain depth and cast shadows.
        t = .04 + .96 * (i + rng.random()) / 56
        angle = i * 2.39996 + rng.uniform(-.3, .3)
        radial = side * math.cos(angle) + up * math.sin(angle)
        root = point(t)
        length = rng.uniform(.065, .105) * (1 - .24 * t)
        tip = root + (radial * .85 + direction * .5) * length
        width = direction.cross(radial).normalized() * rng.uniform(.0045, .0060)
        # A narrow strap retains parallel sides through most of its length;
        # triangular fans exaggerated leaf width in close gameplay views.
        shoulder = root.lerp(tip, .82)
        material = rng.choices([2, 3, 4, 5], [3, 5, 3, 1])[0]
        face([root - width, root + width, shoulder + width * .55, tip - width * .55], material)


for i in range(18):
    a = Vector((.035 * math.sin(i * .6), 0, i * .5))
    b = Vector((.035 * math.sin((i + 1) * .6), 0, (i + 1) * .5))
    limb(a, b, .29 * (1 - i / 19) ** 1.2, .29 * (1 - (i + 1) / 19) ** 1.2)

# Staggered whorls, unequal lengths and missing sectors break the bottle-brush.
for level in range(16):
    height = 1.65 + level * .43
    radius = 2.7 * (1 - (height - 1.4) / 8.0) ** .83
    phase = rng.random() * math.tau
    for branch in range(7):
        if rng.random() < .14:
            continue
        angle = phase + branch * math.tau / 7 + rng.uniform(-.18, .18)
        radial = Vector((math.cos(angle), math.sin(angle), 0))
        lateral = Vector((-math.sin(angle), math.cos(angle), 0))
        length = radius * rng.uniform(.55, 1.20) * (1 + .16 * math.cos(angle - 1.1))
        a = Vector((0, 0, height + rng.uniform(-.38, .38)))
        rise = rng.uniform(-.48, .60)
        sag = rng.uniform(.12, .55)
        sweep = rng.uniform(-.38, .38)
        def bough(t):
            return a + radial * length * t + lateral * sweep * math.sin(math.pi * t) + Vector((0, 0, rise * t - sag * math.sin(math.pi * t)))
        end = bough(1)
        for segment in range(6):
            t0, t1 = segment / 6, (segment + 1) / 6
            r0 = .003 + .033 * (1 - level / 20) * (1 - t0) ** 1.4
            r1 = .003 + .033 * (1 - level / 20) * (1 - t1) ** 1.4
            limb(bough(t0), bough(t1), r0, r1)
        # Independent insertions break the conspicuous paired fishbone pattern.
        # Short shoots form uneven tufts, with occasional forks at their tips.
        for shoot in range(rng.randint(32, 38)):
            # More shoots cover the inner bough instead of leaving a bare
            # radial skeleton; retain unequal outer tips and open sectors.
            t = .08 + .90 * rng.random() ** 1.25
            base = bough(t)
            sign = rng.choice([-1, 1])
            direction = radial * rng.uniform(.25, .95) + lateral * sign * rng.uniform(.35, .95) + Vector((0, 0, rng.uniform(-.90, .65)))
            size = rng.uniform(.36, .62) * (1 - level / 28) * (1 - t * .18)
            spray(base, direction, size)
            if rng.random() < .80:
                fork = base + direction.normalized() * size * .6
                spray(fork, radial * .7 - lateral * sign * .4 + Vector((0, 0, .3)), size * .65)
        spray(end, radial + Vector((0, 0, .6)), .38 * (1 - level / 23))
for i in range(15):
    angle = i * 2.4
    spray(Vector((0, 0, 8 + i * .06)), Vector((math.cos(angle), math.sin(angle), 1)), .28)

mesh = bpy.data.meshes.new("BranchingFirGeometry")
mesh.from_pydata(verts, [], faces)
mesh.update()
tree = bpy.data.objects.new("BranchingFir218", mesh)
bpy.context.collection.objects.link(tree)
# Small embedded tile: vertically broken fissures, no external texture dependency.
bark = bpy.data.images.new("FirBark218", width=256, height=256)
pixels = []
for y in range(256):
    for x in range(256):
        u, v = x / 256, y / 256
        warp = .014 * math.sin(v * math.tau * 3) + .006 * math.sin(v * math.tau * 11)
        fissure = max(0, math.cos((u + warp) * math.tau * 23)) ** 14
        grain = math.sin(u * math.tau * 91 + math.sin(v * math.tau * 19)) * .08
        scale = 1 - fissure * .52 + grain + .12 * math.sin(u * math.tau * 7 + math.sin(v * math.tau * 5))
        pixels.extend((.31 * scale, .27 * scale, .22 * scale, 1))
bark.pixels.foreach_set(pixels)
bark.pack()
colors = [(.11, .084, .058), (.14, .105, .073), (.035, .080, .030),
          (.051, .110, .042), (.067, .13, .049), (.105, .17, .060)]
for index, color in enumerate(colors):
    mat = bpy.data.materials.new("Bark" + str(index) if index < 2 else "Needles" + str(index))
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = .87
    if index < 2:
        texture = mat.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = bark
        mat.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    mat.use_backface_culling = False
    mesh.materials.append(mat)
for polygon, slot in zip(mesh.polygons, slots):
    polygon.material_index = slot
    polygon.use_smooth = slot < 2
uv_layer = mesh.uv_layers.new(name="BarkUV")
for polygon, uv in zip(mesh.polygons, uv_faces):
    for loop, coord in zip(polygon.loop_indices, uv):
        uv_layer.data[loop].uv = coord
mesh.normals_split_custom_set_from_vertices(normals)
bpy.context.view_layer.objects.active = tree
tree.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT / "client/assets/realism/fir_full.glb"),
                         export_format="GLB", use_selection=True)
bpy.ops.object.camera_add(location=(0, -20, 4.5))
camera = bpy.context.object
camera.rotation_euler = (math.pi / 2, 0, 0)
camera.data.type = "ORTHO"
camera.data.ortho_scale = 9.5
scene = bpy.context.scene
scene.camera = camera
bpy.ops.object.light_add(type="AREA", location=(-6, -8, 12))
light = bpy.context.object
light.data.energy = 1800
light.data.size = 7
light.rotation_euler = (Vector((0, 0, 4)) - light.location).to_track_quat("-Z", "Y").to_euler()
scene.world = bpy.data.worlds.new("Outdoor canopy fill")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.65, .72, .8, 1)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = .7
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.render.filepath = str(ROOT / "client/assets/realism/fir_background.png")
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/branching_fir.blend"), compress=True)
bpy.ops.render.render(write_still=True)
print(f"BRANCHING_FIR_BUILD_PASS polygons={len(faces)} vertices={len(verts)}")
