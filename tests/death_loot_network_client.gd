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
	var cmd: Dictionary = game.local_command(actor)
	cmd.loot = true
	game.action_command.rpc_id(1, game.network_round_id, cmd, 48)
	while actor.reserve != 300 or game.loot[48].get("amount", 45) != 32:
		assert(Time.get_ticks_msec() < deadline, "Partial pickup failed to replicate")
		await process_frame
	await process_frame
	await process_frame
	assert(game.world.loot_nodes[48].position.distance_to(game.loot[48].p + Vector3.UP * 0.15) < 0.001)
	# Same reliable event with a different ID must not consume another resource.
	game.action_command.rpc_id(1, game.network_round_id, cmd, 49)
	await create_timer(0.2).timeout
	assert(actor.medkits == 0 and game.loot.has(49))
	cmd.seq += 1
	game.action_command.rpc_id(1, game.network_round_id, cmd, 49)
	while actor.medkits != 3 or game.loot.has(49):
		assert(Time.get_ticks_msec() < deadline, "Complete pickup failed to replicate")
		await process_frame
	await process_frame
	await process_frame
	assert(not game.world.loot_nodes.has(49))
	assert(game.loot[48].amount == 32)
	print("DEATH_LOOT_NETWORK_CLIENT_PASS stock=300 remaining=32 reliable_target=ok replay=ok removal=ok")
	game.request_quit()
