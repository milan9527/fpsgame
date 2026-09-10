extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.set_physics_process(false)
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 12000
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	game.set_physics_process(true)
	var actor = game.actors[game.local_id]
	while actor.health == 100 or not actor.grounded:
		assert(Time.get_ticks_msec() < deadline, "Server landing damage did not arrive")
		await process_frame
	assert(actor.health > 40 and actor.health < 100 and actor.armor == 100)
	var landed_health: float = actor.health
	await create_timer(1.5).timeout
	assert(actor.health == landed_health, "Prediction replay cannot duplicate fall damage")
	assert(actor.position.y < 0.1 and actor.prediction_corrections > 5)
	print("FALL_NETWORK_CLIENT_PASS authoritative_health=ok armor=100 landing_reconciliation=ok no_duplicate_damage=ok")
	game.request_quit()
