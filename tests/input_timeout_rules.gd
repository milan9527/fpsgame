extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	var actor = game.actors[1]
	var cmd: Dictionary = game.local_command(actor)
	for value in [-1, 1.5, 2147483648, INF, NAN]:
		cmd.seq = value
		assert(not game.valid_command(cmd))
	cmd.seq = 2147483647
	assert(game.valid_command(cmd))
	cmd.seq = 5
	cmd.weapon = 1.5
	assert(not game.valid_command(cmd))
	cmd.weapon = -1
	cmd.x = 1.0
	cmd.fire = true
	cmd.ads = true
	cmd.sprint = true
	cmd.crouch = true
	cmd.lean = 1.0
	game.apply_command(actor, cmd)
	actor.jump_requested = true
	actor.last_command_msec = 1000
	actor.reload_left = 1.0
	actor.heal_left = 2.0
	game.expire_held_input(actor, 1350)
	assert(actor.shooting and actor.aiming and actor.jump_requested)
	game.expire_held_input(actor, 1351)
	assert(actor.move_input == Vector2.ZERO and not actor.shooting and not actor.sprint and not actor.aiming)
	assert(actor.lean_input == 0 and not actor.crouch and actor.jump_requested)
	assert(actor.reload_left == 1.0 and actor.heal_left == 2.0, "Accepted timed actions are not rolled back")
	game.apply_command(actor, cmd)
	assert(actor.move_input.x == 1 and actor.shooting and actor.aiming)
	print("INPUT_TIMEOUT_RULES_PASS deadline=ok held_state=neutral actions_preserved=ok recovery=ok sequence_bounds=ok integral_weapon=ok")
	game.request_quit()
