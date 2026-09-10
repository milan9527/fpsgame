extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	game.loot = {0: {"p": Vector3(0, 0.1, 18.5), "kind": 5, "amount": 4.0}}
	await physics_frame
	assert(game.pickup(actor, 0))
	assert(actor.grips == 3 and game.loot[0].amount == 1)
	assert(game.receive_grip(actor, game.match_id, 10, 0, true))
	assert(actor.grips == 2 and actor.grip_slots[0] == 1)
	assert(not game.receive_grip(actor, game.match_id, 10, 0, true))
	assert(not game.receive_grip(actor, game.match_id, 11, 1, true))
	actor.reload_left = 1
	assert(not game.receive_grip(actor, game.match_id, 12, 0, false))
	actor.reload_left = 0
	actor.switch_weapon(1)
	assert(game.receive_grip(actor, game.match_id, 13, 1, true))
	actor.switch_weapon(0)
	assert(game.receive_grip(actor, game.match_id, 14, 0, false))
	actor.recoil = 0
	actor.add_recoil()
	var bare: float = actor.recoil
	assert(game.receive_grip(actor, game.match_id, 15, 0, true))
	actor.recoil = 0
	actor.add_recoil()
	assert(is_equal_approx(actor.recoil, bare * 0.8))
	actor.update_weapon_visuals()
	assert(actor.gun_model.has_node("Foregrip") and actor.third_person_gun.has_node("Foregrip"))
	game.ui.inventory.refresh(actor, [])
	assert("REMOVE FOREGRIP" in game.ui.inventory.grip_button.text)
	var clone = game.actors[-1]
	clone.unpack(actor.pack(), false)
	clone.update_weapon_visuals()
	assert(clone.grips == actor.grips and clone.grip_slots == actor.grip_slots)
	assert(clone.third_person_gun.has_node("Foregrip"))
	var state: Dictionary = game.snapshot_solo()
	assert(game.checkpoint.validate(state, game.build_info.content_revision))
	var bad := state.duplicate(true)
	bad.actors[0].grip_slots[0] = 2
	assert(not game.checkpoint.validate(bad, game.build_info.content_revision))
	game.loot.clear()
	var total: int = clone.grips + clone.grip_slots[0] + clone.grip_slots[1] + clone.grip_slots[2]
	game.damage(clone, 10000, 1, true)
	var dropped := 0.0
	for item in game.loot.values():
		if item.kind == 5:
			dropped += item.amount
	assert(dropped == total and clone.grips == 0 and clone.grip_slots == PackedInt32Array([0, 0, 0]))
	actor.grips = 3
	actor.action_tokens = 10
	assert(not game.receive_grip(actor, game.match_id, 20, 0, false))
	assert(actor.grip_slots[0] == 1)
	assert(game.receive_drop(actor, game.match_id, 21, 5, 2))
	assert(actor.grips == 1)
	assert(not game.receive_grip(actor, "stale", 22, 0, false))
	actor.action_tokens = 0
	assert(not game.receive_grip(actor, game.match_id, 23, 0, false))
	game.world.show_loot(game.loot)
	var displayed := false
	for id in game.loot:
		if game.loot[id].kind == 5:
			displayed = game.world.loot_nodes[id].has_node("ForegripDisplay")
	assert(displayed)
	var directory := "user://qa-foregrip-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	game.checkpoint.path = directory + "/checkpoint.dat"
	var legacy: Dictionary = state.duplicate(true)
	legacy.content = "ash-valley-16"
	legacy.loot = {}
	for saved in legacy.actors:
		saved.erase("grips")
		saved.erase("grip_slots")
	var legacy_bytes := var_to_bytes(legacy)
	var file := FileAccess.open(directory + "/legacy.dat", FileAccess.WRITE)
	file.store_buffer(var_to_bytes({"payload": legacy_bytes, "sha": game.checkpoint.digest(legacy_bytes)}))
	file.close()
	var migrated: Dictionary = game.checkpoint.read_copy(directory + "/legacy.dat", game.build_info.content_revision)
	assert(not migrated.is_empty() and migrated.id == legacy.id)
	assert(migrated.actors[0].grips == 0 and migrated.actors[0].grip_slots == PackedInt32Array([0, 0, 0]))
	assert(game.suspend_solo())
	assert(game.resume_solo())
	assert(game.actors[1].grips == 1 and game.actors[1].grip_slots == PackedInt32Array([1, 1, 0]))
	var bot = game.actors[-2]
	bot.grips = 1
	bot.grip_slots.fill(0)
	game.bot_input(bot, 0.02)
	assert(bot.grips == 0 and bot.grip_slots[bot.weapon] == 1)
	print("FOREGRIP_RULES_PASS pickup=ok bot_install=ok equip_detach=ok per_weapon=ok recoil=ok visual_models=ok snapshots=ok save_schema=ok disk_resume=ok previous_save_migration=ok death_drop=ok capacity=ok replay=ok busy=ok rate=ok")
	game.request_quit()
