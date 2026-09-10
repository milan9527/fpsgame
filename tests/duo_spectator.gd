extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.start_solo("duo")
	game.elapsed = 10
	var local = game.actors[1]
	var ally = game.actors[-1]
	game.damage(local, 10000, -2, true)
	game._process(0.016)
	assert(local.downed and not game.spectator.active, "Downed players keep their own camera")
	game.damage(local, 10000, -2, true)
	game._process(0.016)
	assert(game.spectator.active and game.spectator.target_id == -1)
	assert(game.spectator.candidates(game.actors) == [-1])
	assert("FOLLOWING TEAMMATE" in game.ui.spectator_label.text)
	for direction in [-1, 1]:
		game.spectator.cycle(game.actors, direction)
		assert(game.spectator.target_id == -1)
	game.spectator.select(-2, game.actors)
	assert(game.spectator.target_id == -1, "Explicit selection cannot bypass team restriction")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game._unhandled_input(key)
	assert(game.spectator.target_id == -1)
	game.damage(ally, 10000, -2, true)
	game._process(0.016)
	assert(not ally.alive and game.spectator.target_id == 0)
	assert(game.spectator.position.is_equal_approx(local.position + Vector3.UP * 1.6))
	assert("TEAM ELIMINATED" in game.ui.spectator_label.text and "TEAM PLACEMENT  #8" in game.ui.spectator_label.text)
	game.spectator.cycle(game.actors, 1)
	assert(game.spectator.target_id == 0, "An eliminated team cannot cycle into surviving enemies")
	game.start_solo("duo")
	game.elapsed = 10
	game.damage(game.actors[1], 10000, -2, true)
	game.damage(game.actors[1], 10000, -2, true)
	game._process(0.016)
	assert(game.spectator.target_id == -1)
	game.actors[-1].queue_free()
	game.actors.erase(-1)
	game._process(0.016)
	assert(game.spectator.target_id == 0)
	# Solo still follows the general survivor roster after a duo reset.
	game.start_solo()
	game.elapsed = 10
	game.damage(game.actors[1], 10000, -1, true)
	game._process(0.016)
	assert(game.spectator.team_filter == 0 and game.spectator.candidates(game.actors).size() == 15)
	var first: int = game.spectator.target_id
	game.spectator.cycle(game.actors, 1)
	assert(game.spectator.target_id != first)
	print("DUO_SPECTATOR_PASS downed=own_camera teammate_only=ok selection=guarded wiped=locked disconnected=locked solo_reset=ok")
	game.request_quit()
