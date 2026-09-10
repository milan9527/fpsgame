extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 30000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	var saw_pickup := false
	var saw_grenade := false
	var saw_cloud := false
	var saw_heal := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for grenade in game.grenades.values():
			saw_grenade = saw_grenade or (grenade.kind == 1 and grenade.owner_id == -1)
		saw_cloud = saw_cloud or not game.smoke_clouds.is_empty()
		if game.actors.has(-1):
			var bot = game.actors[-1]
			saw_pickup = saw_pickup or bot.smokes == 1
			saw_heal = saw_heal or bot.heal_left > 0
			if saw_heal and bot.health > 30:
				assert(saw_pickup and saw_grenade and saw_cloud and bot.smokes == 0 and bot.medkits == 1)
				print("BOT_UTILITIES_NETWORK_PASS pickup=replicated grenade=replicated smoke=replicated heal=replicated")
				game.request_quit()
				return
	assert(false, "Bot smoke treatment was not replicated")
