"""Keep authored UVs/materials while reducing Android scenery triangle cost."""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[1] / "client/assets/realism"
for name, ratio in [("boulder", .10), ("supply_crate", .15), ("aircon", .12), ("wall_lamp", .15)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root / f"{name}.glb"))
    total = 0
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        modifier = obj.modifiers.new("Android geometry budget", "DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        total += sum(len(face.vertices) - 2 for face in obj.data.polygons)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(root / f"{name}_mobile.glb"),
                             export_format="GLB", use_selection=True, export_apply=True)
    print(f"ANDROID_PROP {name} triangles={total}", flush=True)
