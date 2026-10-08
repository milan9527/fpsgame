"""Reduce third-person weapon geometry without changing authored attachments."""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[1] / "client/assets"
for name in ("carbine", "shotgun", "marksman"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Import the released asset to retain its baked textures and node transforms.
    bpy.ops.import_scene.gltf(filepath=str(root / f"{name}.glb"))
    before = after = 0
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        triangles = sum(len(face.vertices) - 2 for face in obj.data.polygons)
        before += triangles
        if triangles > 200:
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            # Reduce each material region separately: whole-mesh collapse can
            # erase small painted markings and scope details entirely.
            original_name = obj.name
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.separate(type="MATERIAL")
            bpy.ops.object.mode_set(mode="OBJECT")
            pieces = list(bpy.context.selected_objects)
            for piece in pieces:
                bpy.context.view_layer.objects.active = piece
                region_triangles = sum(len(face.vertices) - 2 for face in piece.data.polygons)
                if region_triangles > 200:
                    modifier = piece.modifiers.new("Android third-person geometry", "DECIMATE")
                    modifier.ratio = 0.20
                    modifier.use_collapse_triangulate = True
                    bpy.ops.object.modifier_apply(modifier=modifier.name)
            bpy.context.view_layer.objects.active = obj
            if len(pieces) > 1:
                bpy.ops.object.join()
            obj.name = original_name
        after += sum(len(face.vertices) - 2 for face in obj.data.polygons)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(root / f"{name}_mobile.glb"),
        export_format="GLB", use_selection=True, export_apply=True,
    )
    print(f"ANDROID_WEAPON {name} triangles_before={before} triangles_after={after}",
          flush=True)
