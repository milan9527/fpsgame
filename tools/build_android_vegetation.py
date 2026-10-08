"""Derive mobile vegetation meshes while retaining authored materials and UVs."""
from pathlib import Path
import math
import random
import sys
import bpy
import bmesh
import numpy as np


def simplify_birch_leaves(obj):
    """Keep crown coverage; collapse decimation deletes disconnected leaves."""
    mesh = obj.data
    leaf_slots = {i for i, mat in enumerate(mesh.materials)
                  if mat and mat.name.startswith("leaf_")}
    bm = bmesh.new()
    bm.from_mesh(mesh)
    # glTF splits vertices at flat normals; reconnect each folded leaf before
    # counting components, otherwise every triangle becomes a separate leaf.
    leaf_vertices = {v for f in bm.faces if f.material_index in leaf_slots
                     for v in f.verts}
    bmesh.ops.remove_doubles(bm, verts=list(leaf_vertices), dist=0.00001)
    bm.verts.index_update()
    leaf_faces = {face for face in bm.faces
                  if face.material_index in leaf_slots}
    remaining = set(leaf_faces)
    components = []
    # Stable order is essential: set iteration must not choose retained leaves.
    bm.faces.ensure_lookup_table()
    for face in bm.faces:
        if face not in remaining:
            continue
        remaining.remove(face)
        pending, group = [face], []
        while pending:
            current = pending.pop()
            group.append(current)
            for vertex in current.verts:
                for neighbour in vertex.link_faces:
                    if neighbour in remaining:
                        remaining.remove(neighbour)
                        pending.append(neighbour)
        components.append(group)
    rng = random.Random(237091)
    cards = []
    source_area = sum(face.calc_area() for face in leaf_faces)
    # One larger two-sided leaf cluster per four authored leaves. The area
    # compensation preserves projected canopy coverage without alpha overdraw.
    for index, group in enumerate(components):
        if index % 4 == 0:
            selected = rng.randrange(4)
        if index % 4 != selected:
            continue
        points = np.array([tuple(vertex.co) for vertex in
                           sorted({v for f in group for v in f.verts},
                                  key=lambda v: v.index)])
        center = points.mean(axis=0)
        _, _, axes = np.linalg.svd(points - center, full_matrices=False)
        coordinates = (points - center) @ axes.T
        half_length = np.ptp(coordinates[:, 0]) / 2
        half_width = np.ptp(coordinates[:, 1]) / 2
        area = sum(face.calc_area() for face in group)
        diamond_area = 2 * half_length * half_width
        scale = math.sqrt(4 * area / max(diamond_area, 1e-9))
        long = axes[0] * half_length * scale
        wide = axes[1] * half_width * scale
        cards.append(([center-long, center-wide, center+long, center+wide],
                      group[0].material_index))
    bmesh.ops.delete(bm, geom=list(leaf_faces), context="FACES")
    bm.to_mesh(mesh)
    bm.free()
    # Only wood is decimated; reconstructed leaf clusters remain intact.
    modifier = obj.modifiers.new("Mobile wood budget", "DECIMATE")
    modifier.ratio = .025
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for points, slot in cards:
        vertices = [bm.verts.new(point) for point in points]
        for indices in [(0, 1, 2), (0, 2, 3)]:
            face = bm.faces.new([vertices[i] for i in indices])
            face.material_index = slot
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    print(f"BIRCH_CROWN source_leaves={len(components)} "
          f"mobile_clusters={len(cards)} source_area={source_area:.3f}", flush=True)

root = Path(__file__).resolve().parents[1] / "client/assets/realism"
requested = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for name, ratio in [("verge_fine_shrub", 0.08), ("verge_birch", 0.04)]:
    if requested and name not in requested:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root / f"{name}.glb"))
    total = 0
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        if name == "verge_birch":
            simplify_birch_leaves(obj)
        else:
            modifier = obj.modifiers.new("Mobile triangle budget", "DECIMATE")
            modifier.ratio = ratio
            modifier.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        total += sum(len(face.vertices) - 2 for face in obj.data.polygons)
    if name == "verge_birch" and total > 8608:
        raise RuntimeError(f"Mobile birch exceeds existing budget: {total} > 8608")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(root / f"{name}_mobile.glb"),
                             export_format="GLB", use_selection=True, export_apply=True)
    print(f"ANDROID_VEGETATION {name} triangles={total}", flush=True)
