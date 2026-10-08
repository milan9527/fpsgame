extends SceneTree

# Identical poses can be run against both old and new PCKs.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var capture_width := OS.get_environment("CAPTURE_WIDTH").to_int()
	if capture_width > 0:
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(capture_width, roundi(capture_width * 0.625))
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	print("ENTRANCE_SCENE_READY ms=", Time.get_ticks_msec())
	game.local_profile = null
	await process_frame
	game.start_solo()
	# Diagnostic only: isolate the cost of local-light shadow maps while
	# retaining sun shadows, all geometry, materials, and the recorded camera.
	var local_shadows_disabled := OS.get_environment("CAPTURE_DISABLE_LOCAL_SHADOWS") == "1"
	var disabled_lights := []
	if local_shadows_disabled:
		for light in game.find_children("*", "Light3D", true, false):
			if not light is DirectionalLight3D and light.shadow_enabled:
				disabled_lights.append(str(light.get_path()))
				light.shadow_enabled = false
	print("ENTRANCE_LOCAL_SHADOW_DIAGNOSTIC disabled=", disabled_lights.size())
	print("ENTRANCE_SOLO_READY ms=", Time.get_ticks_msec())
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var poses := [
		{"name": "entrance-oblique", "at": Vector3(40, 0.05, 47), "target": Vector3(35, 2.4, 40.5)},
		{"name": "entrance-close", "at": Vector3(36.2, 0.05, 43), "target": Vector3(35, 2.8, 40.5)},
		{"name": "entrance-inside", "at": Vector3(35.8, 0.25, 37), "target": Vector3(35, 2.7, 41)},
		{"name": "warehouse-rear", "at": Vector3(35.8, 0.25, 37), "target": Vector3(34.0, 1.9, 26)},
		{"name": "workshop-rear", "at": Vector3(-40.2, 0.25, 37), "target": Vector3(-42, 1.9, 28)},
		{"name": "workshop-bench", "at": Vector3(-45.8, 0.25, 30.5), "target": Vector3(-46.9, 1.5, 27.8)}
	]
	var records := []
	for pose in poses:
		var selected_pose := OS.get_environment("CAPTURE_POSE")
		if not selected_pose.is_empty() and pose.name != selected_pose:
			continue
		actor.position = pose.at
		var delta: Vector3 = pose.at + Vector3(0, 1.6, 0) - pose.target
		actor.yaw = atan2(delta.x, delta.z)
		actor.pitch = -atan2(delta.y, Vector2(delta.x, delta.z).length())
		records.append({"name": pose.name, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
			"target": [pose.target.x, pose.target.y, pose.target.z], "yaw_radians": actor.yaw,
			"pitch_radians": actor.pitch, "eye_offset_y": 1.6, "viewport": [root.size.x, root.size.y],
			"diagnostic_local_shadows_disabled": local_shadows_disabled,
			"disabled_shadow_lights": disabled_lights})
		for frame in range(60):
			actor.render_frame(1.0 / 60.0, false, true, false)
		var expected: Vector3 = (pose.target - actor.camera.global_position).normalized()
		assert((-actor.camera.global_basis.z).dot(expected) > 0.998, "Camera must face recorded target")
		game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		for frame in range(5): await process_frame
		var draw_started := Time.get_ticks_msec()
		print("ENTRANCE_DRAW_BEGIN pose=", pose.name, " ms=", draw_started)
		RenderingServer.force_draw(false)
		print("ENTRANCE_DRAW_END pose=", pose.name, " elapsed_ms=", Time.get_ticks_msec() - draw_started)
		assert(root.get_texture().get_image().save_png(output.path_join(pose.name + ".png")) == OK)
	assert(not records.is_empty(), "Requested entrance pose must exist")
	var record_file := FileAccess.open(output.path_join("entrance-camera-poses.json"), FileAccess.WRITE)
	record_file.store_string(JSON.stringify(records, "\t"))
	record_file.close()
	print("ENTRANCE_DIAGNOSTIC_CAPTURE_PASS" if local_shadows_disabled else "ENTRANCE_REVIEW_CAPTURE_PASS",
		" frames=", records.size())
	quit()
