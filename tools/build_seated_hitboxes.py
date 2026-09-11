"""Bake authoritative seated hit boxes from the original Blender skin/actions."""
from pathlib import Path
import hashlib
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/operator.blend"))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
skin = bpy.data.objects["OperatorSkin"]
for track in rig.animation_data.nla_tracks:
    track.mute = True


def godot(vector):
    return [round(vector.x, 7), round(vector.z, 7), round(-vector.y, 7)]


groups = {}
for vertex in skin.data.vertices:
    weighted = [group for group in vertex.groups if group.weight > 0.0001]
    assert len(weighted) == 1 and abs(weighted[0].weight - 1) < 0.0001
    name = skin.vertex_groups[weighted[0].group].name
    groups.setdefault(name, []).append(vertex.index)

poses = {}
for clip in ("SeatedDriver", "SeatedPassenger", "SeatedDowned"):
    action = bpy.data.actions[clip]
    rig.animation_data.action = action
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    transforms = {name: rig.matrix_world @ rig.pose.bones[name].matrix.copy() for name in groups}
    points = {name: [] for name in groups}
    for frame in range(0, 61, 2):
        bpy.context.scene.frame_set(frame)
        evaluated = skin.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        assert len(mesh.vertices) == len(skin.data.vertices), "Topology must preserve skin vertex indices"
        for name, indices in groups.items():
            inverse = transforms[name].inverted()
            points[name].extend(inverse @ (evaluated.matrix_world @ mesh.vertices[i].co) for i in indices)
        evaluated.to_mesh_clear()
    boxes = []
    for name in sorted(groups):
        values = points[name]
        low = Vector(tuple(min(point[axis] for point in values) - 0.0125 for axis in range(3)))
        high = Vector(tuple(max(point[axis] for point in values) + 0.0125 for axis in range(3)))
        transform = transforms[name]
        boxes.append({"bone": name, "headshot": name == "Head",
                      "origin": godot(transform.translation),
                      "basis": [godot(transform.to_3x3().col[i]) for i in range(3)],
                      "min": [round(value, 7) for value in low],
                      "size": [round(value, 7) for value in high - low]})
    poses[clip] = boxes

data = {"version": 1, "margin": 0.0125, "sample_frames": list(range(0, 61, 2)),
        "source_sha256": hashlib.sha256((ROOT / "art/operator.blend").read_bytes()).hexdigest(),
        "model_sha256": hashlib.sha256((ROOT / "client/assets/operator.glb").read_bytes()).hexdigest(),
        "poses": poses}
target = ROOT / "client/assets/seated_hitboxes.json"
target.write_text(json.dumps(data, indent=2) + "\n")
print("SEATED_HITBOX_BAKE_PASS poses=3 rigid_skin=ok animation_envelope=ok boxes=" +
      str(sum(len(boxes) for boxes in poses.values())))
