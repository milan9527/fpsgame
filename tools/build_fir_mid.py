"""Build middle/far-distance firs from the retained near GLB.

Blender background script. Keep whole needle islands, never random triangles:
use --far for the distant tier; widen retained needles around their centres.
The original near asset and its authoring source remain untouched.
"""
from pathlib import Path
import json
import sys
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[1]
FAR = "--far" in sys.argv
KEEP = 1 if FAR else 4
WIDTH = 3.4 if FAR else 1.8
NAME = "far" if FAR else "mid"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "client/assets/realism/fir_full.glb"))
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
report = []
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    bpy.context.view_layer.objects.active = obj
    material = obj.data.materials[0].name
    if "needles" in material.lower():
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        mesh.verts.ensure_lookup_table()
        seen = set()
        removed = []
        islands = 0
        for vertex in mesh.verts:
            if vertex.index in seen:
                continue
            stack = [vertex]
            seen.add(vertex.index)
            island = []
            while stack:
                current = stack.pop()
                island.append(current)
                for edge in current.link_edges:
                    other = edge.other_vert(current)
                    if other.index not in seen:
                        seen.add(other.index)
                        stack.append(other)
            # Integer hash avoids periodic rows in source needle ordering.
            keep = ((islands * 2654435761) & 0xFFFFFFFF) % 17 < KEEP
            islands += 1
            if not keep:
                removed.extend(island)
                continue
            centre = sum((v.co for v in island), island[0].co * 0) / len(island)
            for v in island:
                v.co = centre + (v.co - centre) * WIDTH
        bmesh.ops.delete(mesh, geom=removed, context="VERTS")
        mesh.to_mesh(obj.data)
        mesh.free()
    else:
        modifier = obj.modifiers.new("Distance branch reduction", "DECIMATE")
        modifier.ratio = 0.12 if FAR else 0.3
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    report.append({"material": material, "before": before, "after": after})
    print(f"FIR_{NAME.upper()}_PART", report[-1], flush=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / f"client/assets/realism/fir_{NAME}.glb"),
    export_format="GLB", use_selection=True, export_apply=True)
report_path = ROOT / ("artifacts/realism433-validation/fir-far-build.json" if FAR
                      else "artifacts/realism432-validation/fir-mid-build.json")
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(
    json.dumps(report, indent=2) + "\n")
print(f"FIR_{NAME.upper()}_BUILD_PASS", flush=True)
