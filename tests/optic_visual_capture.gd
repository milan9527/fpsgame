extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 80 + other.actor_id)
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	actor.yaw = 0
	actor.pitch = 0
	actor.switch_weapon(2)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	for ads in [false, true]:
		# Settle animation numerically; only render the frames needed for a still.
		for frame in range(90):
			actor.render_frame(1.0 / 60.0, false, true, ads)
		game.ui.sight_aiming = ads
		game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("marksman-%s.png" % ("aim" if ads else "hip"))) == OK)
	print("OPTIC_CAPTURE_PASS")
	quit()
