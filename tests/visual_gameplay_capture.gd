extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = atan2(-18, 16)
	actor.pitch = -0.03
	actor.render_frame(0.02, false, true, false)
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_ARTIFACT_DIR").path_join("gameplay.png"))
	print("VISUAL_GAMEPLAY_CAPTURE_PASS")
	quit()
