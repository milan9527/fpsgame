"""Derive the mobile character from the current authored rig and materials."""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root / "art/operator.blend"))
before = after = 0
for obj in list(bpy.context.scene.objects):
    if obj.type != "MESH":
        continue
    before += sum(len(face.vertices) - 2 for face in obj.data.polygons)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new("Android character geometry", "DECIMATE")
    modifier.ratio = 0.25
    modifier.use_collapse_triangulate = True
    # Collapse the rest mesh before skinning, retaining weights and UVs.
    bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    after += sum(len(face.vertices) - 2 for face in obj.data.polygons)
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=str(root / "client/assets/operator_mobile.glb"),
    export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
)
print(f"ANDROID_OPERATOR triangles_before={before} triangles_after={after}", flush=True)
