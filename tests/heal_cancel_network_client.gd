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
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	var actor = game.actors[game.local_id]
	game.ui.set_inventory(true)
	game.ui.inventory.heal_button.pressed.emit()
	while actor.heal_left <= 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	await create_timer(0.4).timeout
	assert(game.ui.inventory.heal_button.text == "CANCEL MEDKIT")
	game.ui.inventory.heal_button.pressed.emit()
	while actor.heal_left > 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.health == 30 and actor.medkits == 2)
	game.ui.inventory.heal_button.pressed.emit()
	while actor.health == 30:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.health == 95 and actor.medkits == 1)
	var late: Dictionary = game.local_command(actor)
	late.cancel_heal = true
	game.action_command.rpc_id(1, game.network_round_id, late)
	await create_timer(0.3).timeout
	assert(actor.heal_left <= 0 and actor.health == 95 and actor.medkits == 1)
	game.ui.inventory.heal_button.pressed.emit()
	while actor.heal_left <= 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.action_command.rpc_id(1, game.network_round_id, late)
	await create_timer(0.3).timeout
	assert(actor.heal_left > 0, "Old cancel replay cannot stop a newer treatment")
	game.ui.inventory.heal_button.pressed.emit()
	while actor.heal_left > 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.medkits == 1 and actor.health == 95)
	print("HEAL_CANCEL_NETWORK_PASS inventory=ok cancelled_stock=ok completion=ok late_intent=ok replay=ok")
	game.request_quit()
