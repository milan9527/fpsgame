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
	game.sound.volume = 1
	game.sound.update_actors(game.actors, game.world, game.actors[1].camera)
	for i in range(64):
		game.sound.effect("explosion", game.actors[1].eye_position(), true, 1, 2)
	assert(game.sound.voices.size() == game.sound.MAX_VOICES)
	for i in range(30):
		if game.sound.voices.is_empty():
			break
		await create_timer(0.1).timeout
	assert(game.sound.voices.is_empty(), "Finished voices leave the active pool")
	for i in range(64):
		game.sound.effect("gun_ar", game.actors[1].eye_position(), true, 1, 2)
	print("AUDIO_SHUTDOWN_PENDING active_voices=48")
	# Exercise the same close notification used by the desktop window manager.
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
