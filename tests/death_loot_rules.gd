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
	var victim = game.actors[-1]
	var collector = game.actors[1]
	victim.position = Vector3(0, 0.02, 20)
	collector.position = Vector3(1, 0.02, 20)
	victim.magazines = PackedInt32Array([7, 2, 1])
	victim.reserve = 27
	victim.medkits = 3
	victim.grenades = 2
	game.drop_inventory(victim)
	assert(game.loot.is_empty(), "Living actors cannot drop through death path")
	game.damage(victim, 10000, collector.actor_id, true)
	assert(game.loot.size() == 3)
	assert(victim.total_ammunition() == 0 and victim.medkits == 0 and victim.grenades == 0)
	var ids := {}
	for id in game.loot:
		ids[int(game.loot[id].kind)] = id
	assert(game.loot[ids[0]].amount == 37 and game.loot[ids[1]].amount == 3 and game.loot[ids[3]].amount == 2)
	var before: int = game.loot.hash()
	game.damage(victim, 10000, collector.actor_id, true)
	game.drop_inventory(victim)
	assert(game.loot.hash() == before, "Repeated death cannot duplicate loot")
	await physics_frame
	await physics_frame
	collector.reserve = 290
	assert(game.pickup(collector, ids[0]) and collector.reserve == 300)
	assert(game.loot[ids[0]].amount == 27)
	collector.reserve = 0
	assert(game.pickup(collector, ids[0]) and collector.reserve == 27)
	collector.medkits = 4
	assert(game.pickup(collector, ids[1]) and game.loot[ids[1]].amount == 2)
	collector.grenades = 3
	assert(game.pickup(collector, ids[3]) and game.loot[ids[3]].amount == 1)
	game.world.show_loot(game.loot)
	assert(is_equal_approx(game.world.loot_nodes[ids[3]].mesh.size.y, 0.2))
	if "--capture-death-loot" in OS.get_cmdline_user_args():
		collector.position = Vector3(0, 0.02, 22)
		collector.pitch = -0.35
		collector.render_frame(0.016, false, true, false)
		for frame in range(90):
			game._process(0.016)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/death-loot.png")
	# A second elimination must not overwrite uncollected remnants.
	game.damage(collector, 10000, 0, true)
	assert(game.loot.has(ids[1]) and game.loot[ids[1]].amount == 2)
	assert(game.loot.has(ids[3]) and game.loot[ids[3]].amount == 1)
	var empty = game.actors[-3]
	empty.magazines = PackedInt32Array([0, 0, 0])
	empty.reserve = 0
	empty.medkits = 0
	empty.grenades = 0
	before = game.loot.hash()
	game.damage(empty, 10000, 0, true)
	assert(game.loot.hash() == before, "Empty victim generates no supplies")
	game.reset_round()
	assert(game.loot.size() == 48 and game.next_loot_id == 48)
	print("DEATH_LOOT_RULES_PASS transfer=ok magazines=ok partial=ok duplicate=ok distinct_ids=ok empty=ok render=ok reset=ok")
	game.queue_free()
	await process_frame
	quit()
