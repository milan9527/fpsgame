extends SceneTree

# Identical poses can be run against both old and new PCKs.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Avoid repeatedly drawing the complete world while settling a static pose.
	RenderingServer.render_loop_enabled = false
	var diagnostic_width := OS.get_environment("CAPTURE_WIDTH").to_int()
	if diagnostic_width > 0:
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(diagnostic_width, roundi(diagnostic_width * 0.625))
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	print("SERVICE_CAPTURE_STAGE world_added ms=", Time.get_ticks_msec())
	game.local_profile = null
	await process_frame
	game.start_solo()
	print("SERVICE_CAPTURE_STAGE solo_started ms=", Time.get_ticks_msec())
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var poses := [{"name": "service-shelter", "at": Vector3(15.5,0.05,40), "target": Vector3(15.5,2.6,29.5)}]
	var records := []
	for pose in poses:
		actor.position = pose.at
		var delta: Vector3 = pose.at + Vector3(0, 1.6, 0) - pose.target
		actor.yaw = atan2(delta.x, delta.z)
		actor.pitch = -atan2(delta.y, Vector2(delta.x, delta.z).length())
		records.append({"name": pose.name, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
			"target": [pose.target.x, pose.target.y, pose.target.z], "yaw_radians": actor.yaw,
			"pitch_radians": actor.pitch, "eye_offset_y": 1.6, "viewport": [root.size.x, root.size.y]})
		for frame in range(60):
			actor.render_frame(1.0 / 60.0, false, true, false)
		game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		for frame in range(5): await process_frame
		print("SERVICE_CAPTURE_STAGE before_draw ms=", Time.get_ticks_msec())
		RenderingServer.force_draw(false)
		print("SERVICE_CAPTURE_STAGE after_draw ms=", Time.get_ticks_msec())
		assert(root.get_texture().get_image().save_png(output.path_join(pose.name + ".png")) == OK)
		if OS.get_environment("CAPTURE_GROUND_TRIM_COMPARE") == "1":
			var grounds: Array[Node] = game.find_children("ServiceYardGround", "MeshInstance3D", true, false)
			assert(grounds.size() == 1)
			var ground: MeshInstance3D = grounds[0]
			var trimmed_mesh := ground.mesh
			var visuals = load("res://scripts/world_visuals.gd")
			var original = visuals.excavated_surface(ground.get_parent(),
				Rect2(-27, 10, 52, 46), ground.material_override, false, 0.044)
			original.visible = false
			var images: Array[Image] = []
			# Same world, pose and frame: swap only the ground mesh.
			for candidate in [original.mesh, trimmed_mesh]:
				ground.mesh = candidate
				RenderingServer.force_draw(false)
				images.append(root.get_texture().get_image())
				print("SERVICE_CAPTURE_STAGE comparison_draw count=", images.size(), " ms=", Time.get_ticks_msec())
			original.queue_free()
			var absolute_error := 0
			var changed := 0
			var before := images[0].get_data()
			var after := images[1].get_data()
			assert(before.size() == after.size())
			for index in range(before.size()):
				absolute_error += absi(int(before[index]) - int(after[index]))
				if before[index] != after[index]:
					changed += 1
			for index in range(2):
				assert(images[index].save_png(output.path_join(
					pose.name + ("-original.png" if index == 0 else "-trimmed.png"))) == OK)
			var report := {"changed_channels": changed,
				"mean_absolute_channel_error": float(absolute_error) / before.size(),
				"scope": "Desktop full scene, same frame ground mesh swap; not Android FPS"}
			var comparison := FileAccess.open(output.path_join(pose.name + "-trim-comparison.json"), FileAccess.WRITE)
			comparison.store_string(JSON.stringify(report, "\t"))
			comparison.close()
			assert(report.mean_absolute_channel_error < 0.1, "Ground trim changed full scene")
	var record_file := FileAccess.open(output.path_join("service-camera-poses.json"), FileAccess.WRITE)
	record_file.store_string(JSON.stringify(records, "\t"))
	record_file.close()
	print("SERVICE_YARD_REVIEW_CAPTURE_PASS frames=", poses.size())
	quit()
