"""Blender: derive the mobile crown from the existing authored distant fir."""
from pathlib import Path
import runpy
import bpy

root = Path(__file__).resolve().parents[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / "client/assets/realism/fir_far.glb"))
total = 0
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("Mobile triangle budget", "DECIMATE")
    modifier.ratio = 0.12
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    total += sum(len(face.vertices) - 2 for face in obj.data.polygons)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(root / "client/assets/realism/fir_mobile.glb"),
    export_format="GLB", use_selection=True, export_apply=True,
)
# Preserve the authored crown geometry while sharing one palette material.
# Load relative to this script because Blender does not guarantee sys.path.
merge = runpy.run_path(str(root / "tools/merge_mobile_fir.py"))["merge"]
mobile = root / "client/assets/realism/fir_mobile.glb"
merge(mobile, mobile)
print(f"ANDROID_FIR_TRIANGLES={total}", flush=True)
