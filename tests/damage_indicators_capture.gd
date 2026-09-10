extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_training()
	await create_timer(2).timeout
	var actor = game.actors[1]
	for offset in [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		game.ui.combat_feedback(1, 10, false, false, actor.position + offset * 10)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	game.request_quit()
