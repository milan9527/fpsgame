extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Grass transforms require a rendering server")
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var exclusions: Array = game.world.ground_obstacles.duplicate()
	exclusions.append_array(game.world.get_meta("hardscape_bounds", []))
	var cells := 0
	var tufts := 0
	var min_height := INF
	var max_height := 0.0
	var min_dry := 1.0
	var max_dry := 0.0
	for node in game.world.get_children():
		if not node is MultiMeshInstance3D: continue
		if not node.material_override is ShaderMaterial: continue
		if node.material_override.shader.resource_path != "res://shaders/grass.gdshader": continue
		cells += 1
		assert(node is MultiMeshInstance3D)
		assert(node.multimesh.mesh.get_aabb().size.y > 0.1, "Imported leaves must stand upright")
		assert(node.multimesh.use_custom_data, "Grass color variation must reach the shader")
		for index in range(node.multimesh.instance_count):
			var placement: Transform3D = node.multimesh.get_instance_transform(index)
			min_height = minf(min_height, placement.basis.y.length())
			max_height = maxf(max_height, placement.basis.y.length())
			var variation: Color = node.multimesh.get_instance_custom_data(index)
			min_dry = minf(min_dry, variation.r)
			max_dry = maxf(max_dry, variation.r)
			var point: Vector3 = node.to_global(placement.origin)
			assert(absf(point.y - 0.01) < 0.001, "Tuft roots must sit on ground")
			assert(absf(point.x) >= 10 and absf(point.z) >= 9, "Main roads must remain clear")
			for obstacle in exclusions:
				assert(not obstacle.grow(0.49).has_point(Vector2(point.x, point.z)),
					"Grass must not grow through buildings or paved areas")
			tufts += 1
	assert(cells > 100 and tufts > 10000, "Imported grass coverage missing")
	assert(max_height > min_height * 2.0, "Grass must retain visibly different heights")
	assert(max_dry - min_dry > 0.5, "Grass must retain green and dry variation")
	print("GRASS_VARIATION_PASS height=%.3f..%.3f dry=%.3f..%.3f" % [min_height, max_height, min_dry, max_dry])
	var actor = game.actors[game.local_id]
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = atan2(-18, 16)
	actor.pitch = -0.48
	actor.render_frame(0.02, false, true, false)
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	assert(root.get_texture().get_image().save_png(output.path_join("grass-close.png")) == OK)
	print("GRASS_VISUAL_PASS cells=%d tufts=%d roots=grounded roads=clear hardscape=clear" % [cells, tufts])
	quit()
