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
	game.elapsed = 10
	game.sound.volume = 0
	var local = game.actors[1]
	game._process(1.0 / 60)
	assert(not game.spectator.active and local.camera.current, "Living players retain their own camera")
	game.spectator.cycle(game.actors, 1)
	assert(game.spectator.target_id == 0, "Living players cannot select another view")
	game.damage(local, 10000, -1, true)
	game._process(1.0 / 60)
	assert(game.spectator.active and game.spectator.camera.current)
	assert(game.ui.spectating and "PLACEMENT  #16" in game.ui.spectator_label.text)
	assert(local.body_mesh.visible and not local.gun.visible)
	var first: int = game.spectator.target_id
	assert(game.actors[first].alive)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game._unhandled_input(key)
	game._process(1.0 / 60)
	assert(game.spectator.target_id != first, "Input event changes spectator target")
	key.physical_keycode = KEY_Q
	game._unhandled_input(key)
	game._process(1.0 / 60)
	assert(game.spectator.target_id == first, "Previous target reverses selection")
	game.action_latch = {"fire": true, "throw": true, "jump": true}
	var command: Dictionary = game.local_command(local)
	assert(not command.fire and not command.throw and not command.jump and command.weapon == -1)
	assert(game.action_latch.is_empty(), "Dead players send no gameplay actions")
	var followed = game.actors[first]
	followed.position = Vector3(0, 0.01, 20)
	followed.yaw = 0
	game.spectator.select(first, game.actors)
	game._process(1.0 / 60)
	var obstruction = game.world.block(Vector3(0, 2, 22.5), Vector3(6, 4, 0.3), "465a61")
	for i in range(4):
		await physics_frame
	assert(game.spectator.arm.get_hit_length() < 2.5, "Camera retracts before nearby wall")
	assert(game.spectator.camera.global_position.z < 22.2, "Camera remains on target side of wall")
	game.spectator.zoom(-100)
	assert(game.spectator.distance == 1.8)
	game.spectator.zoom(100)
	assert(game.spectator.distance == 8)
	game.spectator.orbit(Vector2(100000, 100000), 0.002)
	assert(absf(game.spectator.orbit_yaw) <= PI and game.spectator.orbit_pitch == -1)
	# Restore a useful framing for an optional real renderer capture.
	game.spectator.select(first, game.actors)
	game.spectator.distance = 4.5
	obstruction.queue_free()
	game._process(1.0 / 60)
	for i in range(4):
		await physics_frame
	if "--capture-spectator" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/spectator.png")
	game.damage(followed, 10000, -1, true)
	game._process(1.0 / 60)
	assert(game.spectator.target_id != first, "Target death automatically chooses another survivor")
	var removed: int = game.spectator.target_id
	game.actors[removed].queue_free()
	game.actors.erase(removed)
	game._process(1.0 / 60)
	assert(game.spectator.target_id != removed, "Roster removal cannot leave a dangling target")
	# All-dead state keeps the established rank-one result and winner text aligned.
	var winner_name := ""
	for actor in game.actors.values():
		if actor.alive:
			winner_name = actor.display_name
			game.damage(actor, 10000, 0, true)
	game.finish_round()
	assert(winner_name != "" and winner_name in game.events[-1])
	var winners := 0
	for actor in game.actors.values():
		if actor.rank == 1:
			winners += 1
	assert(winners == 1)
	var result_events: Array = game.events.duplicate()
	game.finish_round()
	assert(game.events == result_events, "Repeated finish cannot duplicate result events")
	game._process(1.0 / 60)
	assert(game.spectator.target_id == 0 and "AWAITING RESULT" in game.ui.spectator_label.text)
	game.start_solo()
	game._process(1.0 / 60)
	assert(not game.spectator.active and not game.ui.spectating and game.actors[1].camera.current)
	game.leave()
	assert(game.lobby_camera.current and not game.spectator.active and game.ui.menu.visible)
	print("SPECTATOR_RULES_PASS death=ok controls=ok wall=ok target_death=ok disconnect=ok neutral_input=ok all_dead_result=ok idempotent_finish=ok reset=ok")
	game.queue_free()
	await process_frame
	quit()
