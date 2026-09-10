extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 40000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline, "Room authentication timeout")
		await process_frame
	game.bot_client = false
	while game.phase != "live" or game.actors.size() != 16:
		assert(Time.get_ticks_msec() < deadline, "Room did not start its own round")
		await process_frame
	await create_timer(1).timeout
	assert(game.room_id == OS.get_environment("TEST_ROOM_ID"))
	assert(game.actors.has(game.local_id))
	var humans := 0
	for actor in game.actors.values():
		if not actor.is_bot:
			humans += 1
	assert(humans == 1, "Players from different rooms must not share rosters")
	print("MULTIROOM_CLIENT_PASS room=%s match=%s peer=%d humans=%d" % [game.room_id, game.network_round_id, game.local_id, humans])
	game.request_quit()
