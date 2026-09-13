extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = atan2(-18, 16)
	actor.pitch = -0.03
	if OS.get_environment("CAPTURE_FOREST") == "1":
		var tree: Node3D
		for node in game.world.get_children():
			if str(node.name).begins_with("fir_near"):
				tree = node
				break
		assert(tree != null, "Forest capture requires a near tree")
		actor.position = tree.position + Vector3(9, 0.05, 9)
		actor.yaw = PI / 4
		actor.pitch = 0.20
	if OS.get_environment("CAPTURE_INTERIOR") == "1":
		actor.position = Vector3(36, 0.25, 31.5)
		actor.yaw = atan2(5.0, -2.5)
		actor.pitch = -0.12
	actor.render_frame(0.02, false, true, false)
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty(), "Set CAPTURE_ARTIFACT_DIR to an output directory")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	assert(root.get_texture().get_image().save_png(output.path_join("gameplay.png")) == OK)
	print("VISUAL_GAMEPLAY_CAPTURE_PASS")
	quit()
