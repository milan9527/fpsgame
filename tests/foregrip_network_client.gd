extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.set_physics_process(false)
	var deadline := Time.get_ticks_msec() + 16000
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline, "Grip fixture did not start")
		await process_frame
	game.bot_client = false
	game.set_physics_process(true)
	var actor = game.actors[game.local_id]
	if OS.get_environment("GRIP_OBSERVER") == "1":
		var observed := false
		while not observed:
			assert(Time.get_ticks_msec() < deadline, "Remote equipped model did not replicate")
			for other in game.actors.values():
				if other.actor_id != game.local_id and not other.is_bot and other.grip_slots[0] == 1 and other.third_person_gun.has_node("Foregrip"):
					observed = true
			await process_frame
		print("FOREGRIP_OBSERVER_PASS remote_inventory=ok remote_model=ok")
		await create_timer(3).timeout
		game.request_quit()
		return
	game.ui.set_inventory(true)
	while not game.ui.inventory.rows.has(48):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.ui.inventory.rows[48].pressed.emit()
	while actor.grips != 2:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.ui.inventory.grip_button.pressed.emit()
	var replay: int = game.sequence
	while actor.grip_slots[0] != 1:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.grips == 1)
	game.grip_command.rpc_id(1, game.network_round_id, replay, 0, false)
	await create_timer(0.8).timeout
	assert(actor.grip_slots[0] == 1 and actor.grips == 1, "Replayed sequence cannot detach")
	game.ui.inventory.grip_button.pressed.emit()
	while actor.grip_slots[0] != 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.grips == 2)
	game.ui.inventory.weapons[1].pressed.emit()
	while actor.weapon != 1:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.ui.inventory.grip_button.pressed.emit()
	while actor.grip_slots[1] != 1:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.grips == 1 and actor.grip_slots[0] == 0)
	game.inventory_drop(5, 1)
	while actor.grips != 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	assert(actor.grip_slots[1] == 1)
	print("FOREGRIP_NETWORK_PASS pickup=ok equip=ok detach=ok replay=ok switch_slot=ok drop=ok")
	game.request_quit()
