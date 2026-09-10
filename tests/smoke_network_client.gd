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
	var deadline := Time.get_ticks_msec() + 35000
	while game.phase != "live" or not game.actors.has(game.local_id) or not game.loot.has(48):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	game.ui.set_inventory(true)
	game.set_physics_process(true)
	var actor = game.actors[game.local_id]
	while not game.ui.inventory.rows.has(48):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.ui.inventory.rows[48].pressed.emit()
	while actor.smokes != 2:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(not game.loot.has(48))
	game.ui.set_inventory(false)
	Input.action_press("smoke_throw")
	await physics_frame
	await physics_frame
	Input.action_release("smoke_throw")
	while game.smoke_clouds.is_empty():
		assert(Time.get_ticks_msec() < deadline, "Smoke did not replicate")
		await process_frame
	assert(actor.smokes == 1 and actor.grenades == 2 and game.smoke_clouds.size() == 1)
	var cloud_id = game.smoke_clouds.keys()[0]
	while game.smoke_clouds[cloud_id].age < 2:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(game.smoke_visuals.has(cloud_id))
	assert(game.smoke_visuals[cloud_id].position == game.smoke_clouds[cloud_id].p)
	while not game.smoke_clouds.is_empty():
		assert(Time.get_ticks_msec() < deadline, "Cloud did not expire on server")
		await process_frame
	await process_frame
	assert(game.smoke_visuals.is_empty() and actor.smokes == 1)
	print("SMOKE_NETWORK_CLIENT_PASS pickup=ok reliable_throw=ok stock=ok authoritative_cloud=ok visual=ok expiry=ok")
	game.request_quit()
