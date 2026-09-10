extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 25000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	var seen := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		seen = seen or not game.grenades.is_empty()
		if seen and game.grenades.is_empty() and game.actors.has(-1):
			var actor = game.actors[-1]
			assert(actor.position.distance_to(Vector3(0, 0.02, 20)) > 6 and actor.health == 100)
			print("BOT_HAZARDS_NETWORK_PASS grenade=replicated escape=replicated survivor_health=100")
			game.request_quit()
			return
	assert(false, "Grenade avoidance did not replicate")
