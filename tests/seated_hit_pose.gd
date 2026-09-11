extends SceneTree
const Pose = preload("res://scripts/seated_hit_pose.gd")
const History = preload("res://scripts/hit_history.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/seated_hitboxes.json"))
	assert(metadata.model_sha256 == FileAccess.get_sha256("res://assets/operator.glb"))
	var scene := Node3D.new()
	root.add_child(scene)
	var car = load("res://scripts/vehicle.gd").new()
	scene.add_child(car)
	var actor = load("res://scripts/actor.gd").new()
	actor.actor_id = 1
	scene.add_child(actor)
	actor.vehicle_ref = weakref(car)
	actor.vehicle_seat = 0
	var checked := 0
	for variant in range(3):
		actor.vehicle_seat = mini(variant, 1)
		actor.downed = variant == 2
		for sample in [0.0, 0.5, 1.0, 1.5]:
			actor.render_frame(0, false, false, false)
			var animation = actor.character_animation
			animation.player.seek(sample, true)
			animation.skeleton.force_update_all_bone_transforms()
			await process_frame
			await RenderingServer.frame_post_draw
			var pose: Dictionary = Pose.capture(actor)
			var by_bone := {}
			for box in pose.boxes:
				by_bone[box.bone] = box
			for node in actor.body_mesh.find_children("*", "MeshInstance3D", true, false):
				if node.skin == null:
					continue
				var baked: ArrayMesh = node.bake_mesh_from_current_skeleton_pose()
				for surface in range(node.mesh.get_surface_count()):
					var original: Array = node.mesh.surface_get_arrays(surface)
					var vertices: PackedVector3Array = baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					var indices: PackedInt32Array = original[Mesh.ARRAY_BONES]
					var weights: PackedFloat32Array = original[Mesh.ARRAY_WEIGHTS]
					var stride: int = indices.size() / vertices.size()
					for i in range(vertices.size()):
						var bind := -1
						for j in range(stride):
							if weights[i * stride + j] > 0.99:
								bind = indices[i * stride + j]
						assert(bind >= 0)
						var bone: String = node.skin.get_bind_name(bind)
						if bone.is_empty():
							bone = animation.skeleton.get_bone_name(node.skin.get_bind_bone(bind))
						assert(by_bone.has(bone), bone)
						var box: Dictionary = by_bone[bone]
						var point: Vector3 = actor.global_transform.affine_inverse() * (node.global_transform * vertices[i])
						assert(box.bounds.grow(0.0001).has_point(box.transform.affine_inverse() * point), "%s sample=%s point=%s" % [bone, sample, point])
						checked += 1
	actor.downed = false
	actor.vehicle_seat = 0
	var pose := Pose.capture(actor)
	var head: Dictionary = pose.boxes.filter(func(box): return box.headshot)[0]
	var center: Vector3 = head.transform * head.bounds.get_center()
	var hit := Pose.trace(pose, center + Vector3.RIGHT * 3, Vector3.LEFT)
	assert(not hit.is_empty() and hit.headshot and hit.bone == "Head")
	assert(Pose.trace(pose, Vector3(0, 0.15, 3), Vector3.FORWARD).is_empty(), "No standing legs below the seated body")
	assert(Pose.trace(pose, Vector3.ZERO, Vector3.ZERO).is_empty())
	assert(Pose.trace(pose, center + Vector3.RIGHT * 3, Vector3.LEFT, 1).is_empty())
	var rotated := pose.duplicate()
	rotated.p = Vector3(15, 3, -8)
	rotated.basis = Basis(Vector3.UP, 0.8)
	var world_center: Vector3 = rotated.p + rotated.basis * center
	var rotated_hit := Pose.trace(rotated, world_center + rotated.basis.x * 3, -rotated.basis.x)
	assert(not rotated_hit.is_empty() and rotated_hit.headshot)
	var history = History.new()
	history.record(1.0, {1: actor})
	actor.position.x = 1
	history.record(1.1, {1: actor})
	var middle: Dictionary = history.poses_at(1.05)[1]
	assert(is_equal_approx(middle.p.x, 0.5))
	var past: Dictionary = history.trace(1.0, center + Vector3.RIGHT * 3, Vector3.LEFT, 180, 2, {1: actor})
	assert(past.collider == actor and past.headshot)
	assert(actor.position.x == 1, "Analytic rewind cannot move live bodies")
	car.seats.epoch += 1
	history.record(1.2, {1: actor})
	assert(history.poses_at(1.15).is_empty())
	assert(history.poses_at(1.1).has(1), "Exact sample boundary keeps its valid pose")
	actor.vehicle_ref = null
	actor.vehicle_seat = -1
	history.record(1.3, {1: actor})
	assert(history.poses_at(1.25).is_empty(), "Do not sweep a seated actor into a standing capsule")
	actor.alive = false
	assert(history.trace(1.0, center + Vector3.RIGHT * 3, Vector3.LEFT, 180, 2, {1: actor}).is_empty())
	scene.queue_free()
	await process_frame
	print("SEATED_HIT_POSE_PASS baked_vertices=%d driver=ok passenger=ok downed=ok head=ok seated_gap=ok history=ok epoch=ok exit_transition=ok dead=ok" % checked)
	quit()
