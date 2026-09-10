extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	# Keep its real login/ENet pipeline, but drive this test's inputs explicitly.
	game.set_physics_process(false)
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 10000
	while game.phase != "live" or not game.actors.has(game.local_id) or not game.loot.has(48):
		assert(Time.get_ticks_msec() < deadline, "Timed out waiting for fixture round")
		await process_frame
	game.bot_client = false
	var actor = game.actors[game.local_id]
	assert(actor.reserve == 295)
	game.ui.set_inventory(true)
	# Resume the real prediction/reconciliation loop once scripted bot input is
	# disabled. Server teleports in the fixture arrive as pending corrections.
	game.set_physics_process(true)
	while not game.ui.inventory.rows.has(48) or not game.ui.inventory.rows.has(49):
		assert(Time.get_ticks_msec() < deadline, "Nearby inventory did not follow reconciled position")
		await process_frame
	assert(not paused and game.ui.inventory.rows.has(48) and game.ui.inventory.rows.has(49))
	game.ui.inventory.rows[49].pressed.emit()
	while actor.medkits != 3 or game.loot.has(49):
		assert(Time.get_ticks_msec() < deadline, "Inventory medicine selection failed")
		await process_frame
	game._process(0.016)
	assert(not game.ui.inventory.rows.has(49))
	game.ui.inventory.rows[48].pressed.emit()
	while actor.reserve != 300 or game.loot[48].get("amount", 45) != 32:
		assert(Time.get_ticks_msec() < deadline, "Partial pickup failed to replicate")
		await process_frame
	await process_frame
	await process_frame
	assert(game.world.loot_nodes[48].position.distance_to(game.loot[48].p + Vector3.UP * 0.15) < 0.001)
	game._process(0.016)
	assert(game.ui.inventory.rows[48].disabled)
	game.ui.inventory.weapons[2].pressed.emit()
	while actor.weapon != 2:
		assert(Time.get_ticks_msec() < deadline, "Inventory equip failed")
		await process_frame
	assert(actor.ammo == 5 and actor.reserve == 300)
	game.ui.set_inventory(false)
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	assert(game.loot[48].amount == 32)
	print("INVENTORY_NETWORK_CLIENT_PASS selected_medicine=ok stock=300 remaining=32 equipped=SR neutral_ui=ok removal=ok")
	game.request_quit()
