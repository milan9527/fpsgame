extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null # This fixture must not modify the player's local results.
	await process_frame
	game.start_solo()
	game.running = false
	game.sound.volume = 0
	var player = game.actors[1]
	player.position = Vector3(0, 0.02, 10)
	player.render_frame(0.016, false, true, false)
	var grenade = load("res://scripts/grenade.gd").new()
	grenade.position = Vector3(-0.25, 1.4, 8.5)
	game.add_child(grenade)
	grenade.freeze = true
	game.ui.grenade_warning_distance = 2
	game.ui.update_hud(player, 16, "live", 260, 100, [], "")
	game.grenade_exploded(game.match_id, 100, Vector3(2.5, 0.8, 5))
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	print("GRENADE_RENDER_PASS")
	quit()
