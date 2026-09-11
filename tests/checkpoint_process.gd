extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var location := OS.get_environment("CHECKPOINT_TEST_DIR")
	assert(location != "")
	DirAccess.make_dir_recursive_absolute(location)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.sound.volume = 0
	game.local_profile = load("res://scripts/local_profile.gd").new(location + "/results")
	game.checkpoint.path = location + "/checkpoint.dat"
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var mode := OS.get_environment("CHECKPOINT_MODE")
	if mode.is_empty():
		mode = "solo"
	if "--write-checkpoint" in OS.get_cmdline_user_args():
		game.start_solo(mode)
		game.elapsed = 55
		game.actors[1].health = 61
		game.actors[1].armor = 27
		game.actors[1].magazines = PackedInt32Array([12, 4, 2])
		game.actors[1].reserve = 83
		game.actors[1].reload_left = 0.4
		if mode == "duo":
			game.damage(game.actors[1], 10000, -2, true)
			assert(game.rescue.interact(game, game.actors[-1]))
			game.rescue.update(game, 2)
		assert(game.suspend_solo())
		print("CHECKPOINT_PROCESS_WRITE_PASS id=", game.match_id)
	else:
		assert(game.resume_solo())
		var actor = game.actors[1]
		assert(paused and game.elapsed == 55 and game.match_mode == mode)
		assert(actor.magazines == PackedInt32Array([12, 4, 2]) and actor.reserve == 83)
		if mode == "duo":
			assert(actor.downed and actor.health == 0 and actor.bleed_left == 28 and actor.knock_attacker == -2)
			assert(game.actors[-1].revive_target == 1 and game.actors[-1].revive_left == 3)
			assert(game.teams.friendly(1, -1))
		else:
			assert(actor.health == 61 and actor.armor == 27 and actor.reload_left == 0.4)
		assert(game.suspend_solo())
		assert(game.local_profile.summary().completed == 0 and game.local_profile.summary().abandoned == 0)
		print("CHECKPOINT_PROCESS_READ_PASS id=", game.match_id)
	game.request_quit()
