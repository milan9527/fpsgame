extends "mobile_view_geometry_inventory.gd"

var report := {"scope": "Desktop OpenGL Android asset branches; CPU scan movement is simulated, not presented frames or Android acceptance", "samples": [], "movement": [], "complete": false}

func save_report() -> void:
	var output := OS.get_environment("GRASS_WORLD_OUTPUT")
	assert(not output.is_empty())
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

func draw_sample() -> Dictionary:
	for frame in range(2):
		await process_frame
		RenderingServer.force_draw(false)
	return {
		"draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	}

func hidden_visible_roots(entries: Array, position: Vector3) -> int:
	var missing := 0
	for entry in entries:
		if entry.node.visible or not entry.grass_in_range(position):
			continue
		var node: MultiMeshInstance3D = entry.node
		for i in range(node.multimesh.instance_count):
			var point: Vector3 = node.global_transform * node.multimesh.get_instance_transform(i).origin
			if Vector2(point.x, point.z).distance_squared_to(Vector2(position.x, position.z)) < 24.0 * 24.0:
				missing += 1
	return missing

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	android_branch_script("res://scripts/world_visuals.gd")
	var world_script := android_branch_script("res://scripts/world.gd")
	Mobile = load("res://scripts/mobile_performance.gd")
	var world: Node3D = world_script.new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	Mobile.configure_world(world)
	Mobile.configure_window(root)
	root.size = Vector2i(480, 300)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var controller = Mobile.new()
	var grass: Array = []
	# Include the other static entries: they share the production scan budget.
	controller.register_distance_nodes(world)
	for entry in controller.distance_nodes:
		if entry.grass_fade_squared > 0.0:
			grass.append(entry)
	assert(not grass.is_empty())
	report["device"] = RenderingServer.get_video_adapter_name()
	report["grass_batches"] = grass.size()
	report["distance_entries"] = controller.distance_nodes.size()
	save_report()
	var previous := Vector3(2, 1.6, 61)
	for position in [previous, Vector3(2, 1.6, 21), previous]:
		if position != previous:
			var worst_missing := 0
			var peak_slice_us := 0
			# 10 m/s at 30 updates/s, preserve cursor/timer and visibility.
			# No force_draw here: this checks CPU scheduling, not GPU speed.
			for step in range(1, 121):
				camera.position = previous.lerp(position, step / 120.0)
				controller.cull_seconds -= 1.0 / 30.0
				if controller.cull_seconds <= 0.0 or controller.cull_cursor != 0:
					var started := Time.get_ticks_usec()
					controller.update_distance_visibility(camera.position, started)
					peak_slice_us = maxi(peak_slice_us, Time.get_ticks_usec() - started)
				worst_missing = maxi(worst_missing, hidden_visible_roots(grass, camera.position))
				await process_frame
			report.movement.append({"from": [previous.x, previous.y, previous.z],
				"to": [position.x, position.y, position.z], "simulated_steps": 120,
				"speed_m_s": 10, "update_hz": 30, "hidden_visible_roots_peak": worst_missing,
				"cpu_slice_peak_us": peak_slice_us})
			save_report()
			assert(worst_missing == 0, "Incremental scan hid grass inside shader fade")
		camera.position = position
		camera.look_at(position + Vector3(-2, 1.6, -146))
		while true:
			controller.update_distance_visibility(position, Time.get_ticks_usec())
			if controller.cull_cursor == 0:
				break
		assert(hidden_visible_roots(grass, position) == 0)
		var after := await draw_sample()
		var visibility: Array[bool] = []
		var hidden := 0
		for entry in grass:
			visibility.append(entry.node.visible)
			if not entry.node.visible:
				hidden += 1
			entry.node.visible = true
		var before := await draw_sample()
		# Restore exact post-scan state before the next movement leg.
		for i in range(grass.size()):
			grass[i].node.visible = visibility[i]
		assert(after.draw_calls > 0 and after.primitives > 0)
		assert(after.draw_calls <= before.draw_calls)
		report.samples.append({"position": [position.x, position.y, position.z],
			"before": before, "after": after, "hidden_batches": hidden})
		save_report()
		print("GRASS_WORLD_SAMPLE ", JSON.stringify(report.samples.back()))
		previous = position
	report.complete = true
	save_report()
	controller.free()
	world.queue_free()
	await process_frame
	print("ANDROID_GRASS_WORLD_PASS")
	quit()
