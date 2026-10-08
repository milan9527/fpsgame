extends SceneTree

# Actual actor materials, weapon attachment and world lighting; manual review required.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	actor.local_view = false
	actor.body_mesh.visible = true
	actor.position = Vector3(0, 0.05, 68)
	actor.yaw = 0.0
	actor.pitch = 0.0
	actor.grounded = true
	actor.velocity = Vector3.ZERO
	# Preserve the historical camera fixture only for explicit baseline comparisons.
	# Normal reviews must let the gameplay capsule settle onto the collision floor.
	var legacy_fixture := OS.get_environment("OPERATOR_REVIEW_LEGACY_FIXTURE") == "1"
	if not legacy_fixture:
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		assert(actor.grounded, "Review actor must settle on the gameplay collision floor")
	game.ui.hide()
	var review_camera := Camera3D.new()
	game.add_child(review_camera)
	review_camera.fov = 65.0
	review_camera.make_current()
	var count := 0
	var samples: Array = []
	var stances := ["run"] if OS.get_environment("OPERATOR_REVIEW_RUN_CONTACT") == "1" else ["idle"]
	if not OS.get_environment("OPERATOR_REVIEW_STANCES").is_empty():
		stances = Array(OS.get_environment("OPERATOR_REVIEW_STANCES").split(","))
	for stance in stances:
		actor.crouch = stance == "crouch"
		actor.update_stance()
		actor.downed = stance == "downed"
		actor.reload_left = actor.RELOAD[actor.weapon] * 0.5 if stance == "reload" else 0.0
		for frame in range(12):
			actor.render_frame(1.0 / 60.0, false, false, false)
			# Let deferred skeleton updates finish before sampling the next pose.
			await process_frame
		if stance == "run":
			# Reproduce the measured support-exchange defect at a fixed animation
			# time. Keep the settled gameplay capsule and the existing camera rig.
			var player: AnimationPlayer = actor.body_mesh.find_children("*", "AnimationPlayer", true, false)[0]
			for clip in player.get_animation_list():
				if clip.get_slice("/", clip.get_slice_count("/") - 1) == "Run":
					player.play(clip, 0)
					player.seek(0.177777783, true)
			await process_frame
		for view in [[3.0, 0], [3.0, 90], [10.0, 0], [10.0, 90]]:
			var distance: float = view[0]
			var angle: int = view[1]
			var radians := deg_to_rad(float(angle))
			var focus: Vector3 = actor.position + Vector3(0, 0.95, 0)
			review_camera.position = actor.position + Vector3(sin(radians) * distance, 1.5, -cos(radians) * distance)
			review_camera.look_at(focus)
			for frame in range(4):
				await process_frame
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(output.path_join("%s-%dm-%d.png" % [stance, int(distance), angle])) == OK)
			var contact: Array = []
			var soles := [Vector3(0, INF, 0), Vector3(0, INF, 0)]
			for mesh in actor.body_mesh.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin == null: continue
				var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
				for side in [-1, 1]:
					var index: int = 0 if side == -1 else 1
					for surface in range(baked.get_surface_count()):
						for vertex in baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
							if vertex.x * side <= 0: continue
							var world_vertex: Vector3 = mesh.global_transform * vertex
							if world_vertex.y < soles[index].y: soles[index] = world_vertex
			# Find each foot's lowest vertex across the whole skinned body, not a
			# separate 'sole' for every mesh (which can include head-only meshes).
			for index in range(2):
				var sole: Vector3 = soles[index]
				assert(sole.is_finite(), "Both sides must contain skinned vertices")
				var query := PhysicsRayQueryParameters3D.create(sole + Vector3.UP, sole - Vector3.UP, 1)
				var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
				assert(not hit.is_empty(), "A collision floor must exist below both boots")
				contact.append({"side": -1 if index == 0 else 1, "sole_world": [sole.x, sole.y, sole.z], "floor_y": hit.position.y, "gap_m": sole.y - hit.position.y})
			samples.append({"stance": stance, "legacy_fixture": legacy_fixture, "horizontal_distance_m": distance, "camera_position": [review_camera.position.x, review_camera.position.y, review_camera.position.z], "camera_rotation": [review_camera.rotation.x, review_camera.rotation.y, review_camera.rotation.z], "fov": review_camera.fov, "actor_position": [actor.position.x, actor.position.y, actor.position.z], "angle": angle, "boot_contact": contact})
			count += 1
	var file := FileAccess.open(output.path_join("camera.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "  "))
	file.close()
	print("OPERATOR_GAMEPLAY_CAPTURE_PASS frames=%d; visual inspection required" % count)
	quit()
