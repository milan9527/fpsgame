extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 65000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline, "Capacity authentication timeout")
		await process_frame
	game.bot_client = false
	while game.phase != "live" or game.actors.size() != 16:
		assert(Time.get_ticks_msec() < deadline, "Capacity roster timeout")
		await process_frame
	for actor in game.actors.values():
		assert(not actor.is_bot, "All sixteen slots must be independent clients")
	print("CAPACITY_READY peer=%d match=%s" % [game.local_id, game.network_round_id])
	while not FileAccess.file_exists(OS.get_environment("CAPACITY_BARRIER")):
		assert(Time.get_ticks_msec() < deadline, "Capacity barrier timeout")
		await process_frame
	var initial := {}
	for id in game.actors:
		initial[id] = game.actors[id].position
	var player = game.actors[game.local_id]
	player.pitch = 1.2
	var initial_time: float = game.phase_time
	var observed_movement := {}
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 8000:
		var second := (Time.get_ticks_msec() - start) / 1000
		Input.action_press("forward" if second % 4 < 2 else "back")
		Input.action_release("back" if second % 4 < 2 else "forward")
		Input.action_press("fire")
		assert(game.phase == "live" and game.actors.size() == 16)
		for id in initial:
			if game.actors[id].position.distance_to(initial[id]) > 0.5:
				observed_movement[id] = true
		await process_frame
	Input.action_release("forward")
	Input.action_release("back")
	Input.action_release("fire")
	var moved := observed_movement.size()
	assert(player.ammo < 30 and player.prediction_corrections > 30)
	assert(initial_time - game.phase_time > 5, "Server simulation fell too far behind wall time")
	assert(moved >= 8, "Remote movement did not replicate")
	print("CAPACITY_CLIENT_PASS peer=%d match=%s moved=%d corrections=%d simulated=%.2f" % [game.local_id, game.network_round_id, moved, player.prediction_corrections, initial_time - game.phase_time])
	# Keep all clients connected until the orchestrator has checked every result.
	while not FileAccess.file_exists(OS.get_environment("CAPACITY_BARRIER") + ".exit"):
		assert(Time.get_ticks_msec() < deadline + 20000, "Capacity exit barrier timeout")
		await process_frame
	game.request_quit()
