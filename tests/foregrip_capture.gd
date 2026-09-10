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
	var actor = game.actors[1]
	actor.grips = 2
	assert(game.receive_grip(actor, game.match_id, 10, 0, true))
	game.loot[48] = {"p": Vector3(0.6, 0.1, 18.5), "kind": 5, "amount": 1.0}
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH") + "-weapon.png")
	game.ui.set_inventory(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH") + "-inventory.png")
	game.request_quit()
