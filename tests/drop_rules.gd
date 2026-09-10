extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	game.elapsed = 10
	game.loot.clear()
	var actor = game.actors[1]
	var other = game.actors[-1]
	actor.position = Vector3(0, 0.02, 20)
	other.position = Vector3(1, 0.02, 20)
	await physics_frame
	await physics_frame
	game.ui.set_inventory(true)
	game._process(0.016)
	game.ui.inventory.drop_count.value = 30
	game.ui.inventory.drop_button.pressed.emit()
	assert(actor.reserve == 90 and actor.magazines == PackedInt32Array([30, 8, 5]))
	var id: int = game.loot.keys()[0]
	assert(game.loot[id].amount == 30 and game.loot[id].p == actor.position)
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 30), "Reliable replay must not drop twice")
	game.sequence += 1
	assert(game.receive_drop(actor, game.match_id, game.sequence, 0, 10))
	assert(game.loot.size() == 1 and game.loot[id].amount == 40 and actor.reserve == 80)
	other.reserve = 290
	assert(game.pickup(other, id) and other.reserve == 300 and game.loot[id].amount == 30)
	assert(game.pickup(actor, id) and actor.reserve == 110 and not game.loot.has(id))
	for request in [[0, -1], [0, 0], [0, 999], [2, 1], [4, 1], [0, 111], [0.0, 1], [0, 1.5]]:
		game.sequence += 1
		actor.action_tokens = 10
		assert(not game.receive_drop(actor, game.match_id, game.sequence, request[0], request[1]))
	assert(actor.reserve == 110 and game.loot.is_empty())
	game.sequence += 1
	assert(not game.receive_drop(actor, "old-round", game.sequence, 0, 1))
	assert(not game.receive_drop(actor, game.match_id, 1.5, 0, 1))
	actor.health = 30
	actor.heal()
	game.ui.inventory.drop_kind.select(1)
	game._process(0.016)
	assert(game.ui.inventory.drop_button.disabled)
	game.sequence += 1
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 1, 2))
	actor.simulate(4)
	assert(actor.medkits == 1 and actor.health == 95)
	game.sequence += 1
	assert(game.receive_drop(actor, game.match_id, game.sequence, 1, 1) and actor.medkits == 0)
	game.sequence += 1
	assert(game.receive_drop(actor, game.match_id, game.sequence, 3, 2) and actor.grenades == 0)
	actor.action_tokens = 0
	game.sequence += 1
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 1))
	actor.action_tokens = 10
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 1), "Rate-limited request cannot replay later")
	actor.last_sequence = game.sequence + 200
	game.sequence += 1
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 1))
	actor.last_sequence = 0
	game.phase = "finished"
	game.sequence += 1
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 1))
	game.phase = "live"
	actor.apply_damage(10000)
	assert(not game.receive_drop(actor, game.match_id, game.sequence, 0, 1))
	print("DROP_RULES_PASS ui=ok transfer=ok loaded_preserved=ok merge=ok competing_pickup=ok replay=ok bounds=ok healing=ok rate=ok stale=ok phase=ok death=ok")
	game.queue_free()
	await process_frame
	quit()
