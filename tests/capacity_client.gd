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
	var duration := int(OS.get_environment("CAPACITY_SECONDS")) if OS.has_environment("CAPACITY_SECONDS") else 8
	assert(duration >= 8 and duration <= 45)
	var initial_reserve: int = player.reserve
	var reload_press := false
	while Time.get_ticks_msec() - start < duration * 1000:
		if reload_press:
			Input.action_release("reload")
			reload_press = false
		elif player.ammo == 0 and player.reload_left <= 0 and player.reserve > 0:
			Input.action_press("reload")
			reload_press = true
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
	Input.action_release("reload")
	var moved := observed_movement.size()
	assert(player.ammo < 30 and player.prediction_corrections > 30)
	assert(initial_time - game.phase_time > duration * 0.85, "Server simulation fell too far behind wall time")
	if duration >= 30:
		assert(player.reserve < initial_reserve, "Sustained clients must reload using normal input")
	assert(moved >= 8, "Remote movement did not replicate")
	print("CAPACITY_CLIENT_PASS peer=%d match=%s moved=%d corrections=%d simulated=%.2f reserve_used=%d" % [game.local_id, game.network_round_id, moved, player.prediction_corrections, initial_time - game.phase_time, initial_reserve - player.reserve])
	# Keep all clients connected until the orchestrator has checked every result.
	while not FileAccess.file_exists(OS.get_environment("CAPACITY_BARRIER") + ".exit"):
		assert(Time.get_ticks_msec() < start + duration * 1000 + 25000, "Capacity exit barrier timeout")
		await process_frame
	game.request_quit()
