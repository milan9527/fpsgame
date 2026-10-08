"""Build a metre-scale, folded-leaf understory shrub; no image cards."""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[1]
fine = "--fine-leaf" in sys.argv
asset_name = "verge_fine_shrub" if fine else "verge_shrub"
rng = random.Random(236091 if fine else 220091)
bpy.ops.wm.read_factory_settings(use_empty=True)
vertices, faces, slots = [], [], []
vertex_indices = {}


def face(points, slot):
    indices = []
    for p in points:
        key = tuple(round(v, 7) for v in p)
        if key not in vertex_indices:
            vertex_indices[key] = len(vertices)
            vertices.append(p.copy())
        index = vertex_indices[key]
        if index not in indices:
            indices.append(index)
    if len(indices) < 3:
        return
    faces.append(tuple(indices))
    slots.append(slot)


def twig(a, b, radius):
    axis = (b - a).normalized()
    side = axis.cross(Vector((0, 1, 0))).normalized()
    up = axis.cross(side)
    for i in range(5):
        p = side * math.cos(i * math.tau / 5) + up * math.sin(i * math.tau / 5)
        q = side * math.cos((i + 1) * math.tau / 5) + up * math.sin((i + 1) * math.tau / 5)
        face([a + p * radius, a + q * radius, b + q * radius * .3, b + p * radius * .3], 0)


for stem in range(18 if fine else 12):
    azimuth = rng.uniform(0, math.tau)
    base = Vector((rng.uniform(-.12, .12), rng.uniform(-.12, .12), 0))
    tip = Vector((math.cos(azimuth) * rng.uniform(.3, .6),
                  math.sin(azimuth) * rng.uniform(.3, .6), (rng.uniform(.65, 1.25) if fine else rng.uniform(.45, .95))))
    # Bow the woody stems outward, with shoots distributed around the crown.
    # Straight stems with identical short shoots made a thin wire fan.
    elbow = base.lerp(tip, .52)
    if fine:
        elbow += Vector((math.cos(azimuth) * .14, math.sin(azimuth) * .14, .08))
    twig(base, elbow, .009)
    twig(elbow, tip, .005)
    shoot_count = rng.randint(5, 9) if fine else 7
    for shoot in range(shoot_count):
        fraction = rng.uniform(.26, .96) if fine else .30 + shoot * .10
        at = (base.lerp(elbow, fraction / .52) if fraction < .52
              else elbow.lerp(tip, (fraction - .52) / .48))
        angle = azimuth + (1 if shoot % 2 else -1) * rng.uniform(.6, 1.6)
        reach = rng.uniform(.12, .34) * (1.25 - fraction * .55) if fine else .24
        end = at + Vector((math.cos(angle) * reach, math.sin(angle) * reach,
                           rng.uniform(-.05, .16) if fine else .09))
        twig(at, end, .003)
        leaf_count = rng.randint(7, 11) if fine else 6
        for leaf in range(leaf_count):
            # Irregular short petioles and terminal clusters replace the
            # evenly spaced, alternating ladder of identical blades.
            centre = at.lerp(end, rng.uniform(.38, 1.0) if fine else .2 + leaf * .15)
            leaf_angle = angle + (1 if leaf % 2 else -1) * rng.uniform(.65, 1.6)
            direction = Vector((math.cos(leaf_angle), math.sin(leaf_angle),
                                rng.uniform(-.5, 1.3))).normalized()
            length = rng.uniform(.035, .082) if fine else rng.uniform(.075, .125)
            if fine:
                petiole_end = centre + direction * rng.uniform(.009, .024)
                twig(centre, petiole_end, .0009)
                centre = petiole_end
            # Roll each blade around its midrib. Horizontal-only blades become
            # thin wires at a standing player's eye height, especially in shade.
            lateral = direction.cross(Vector((0, 0, 1))).normalized()
            normal = lateral.cross(direction).normalized()
            roll = rng.uniform(-1.2, 1.2)
            lateral = lateral * math.cos(roll) + normal * math.sin(roll)
            normal = lateral.cross(direction).normalized()
            width = length * (rng.uniform(.17, .25) if fine else rng.uniform(.25, .34))
            slot = rng.choices([1, 2, 3, 4], [4, 5, 3, 1])[0]
            # Curved lanceolate outline and a shallow cupped cross section.
            # Four longitudinal sections avoid the old diamond silhouette.
            rows = []
            for t in ([i / 8 for i in range(9)] if fine else [0.0, .24, .52, .78, 1.0]):
                mid = centre + direction * length * t
                mid += normal * length * (.13 * math.sin(math.pi * t) - .16 * t * t)
                w = width * math.sin(math.pi * t) ** .8
                # Twisted margins break the flat diamond silhouette.
                twist = math.sin(t * math.pi * 1.5) * .32 if fine else 0.0
                rows.append([mid - lateral * w - normal * w * (.30 + twist),
                             mid, mid + lateral * w - normal * w * (.30 - twist)])
            for a, b in zip(rows, rows[1:]):
                for j in range(2):
                    face([a[j], b[j], b[j+1], a[j+1]], slot)

mesh = bpy.data.meshes.new("Folded leaves and branching stems")
mesh.from_pydata(vertices, [], faces)
mesh.update()
obj = bpy.data.objects.new("VergeShrub", mesh)
bpy.context.collection.objects.link(obj)
for name, color in [("twigs", (.16, .12, .068)), ("shade", (.045, .073, .021)),
                    ("olive", (.095, .135, .032)), ("sage", (.14, .18, .055)),
                    ("new_growth", (.20, .23, .085))]:
    if fine and name != "twigs":
        color = (color[0] * .72, color[1] * .87, color[2] * 1.1)
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = .84
    material.use_backface_culling = False
    mesh.materials.append(material)
for poly, slot in zip(mesh.polygons, slots):
    poly.material_index = slot
    poly.use_smooth = slot != 0
bpy.ops.wm.save_as_mainfile(filepath=str(root / f"art/{asset_name}.blend"))
bpy.ops.export_scene.gltf(filepath=str(root / f"client/assets/realism/{asset_name}.glb"), export_format="GLB")
print("SHRUB", len(vertices), "vertices", len(faces), "faces")
