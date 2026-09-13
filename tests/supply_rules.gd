extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sync() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	var actor = game.actors[1]
	var other = game.actors[-1]
	actor.position = Vector3(0, 0.02, 20)
	other.position = Vector3(1, 0.02, 20)
	actor.yaw = 0
	actor.pitch = 0
	game.loot = {7: {"p": Vector3(0, 0.1, 18.3), "kind": 0}}
	await sync()
	actor.reserve = 300
	assert(not game.pickup(actor) and game.loot.has(7), "Full inventory preserves the item")
	actor.reserve = 295
	var before_hash: int = game.loot.hash()
	assert(game.pickup(actor) and actor.reserve == 300)
	assert(game.loot[7].amount == 40 and game.loot.hash() != before_hash, "Partial quantity changes reliable world state")
	other.reserve = 270
	assert(game.pickup(other, 7) and other.reserve == 300 and game.loot[7].amount == 10)
	actor.reserve = 0
	assert(not game.pickup(actor, 999) and actor.reserve == 0, "Missing explicit target cannot fall back")
	assert(game.pickup(actor, 7) and actor.reserve == 10 and not game.loot.has(7), "Competing pickups conserve all 45 rounds")
	for kind in [1, 2, 3]:
		var field: String = game.SupplyRules.FIELDS[kind]
		var limit: float = game.SupplyRules.LIMITS[kind]
		actor.set(field, limit - 0.5 if kind == 2 else int(limit) - 1)
		game.loot = {7: {"p": Vector3(0, 0.1, 18.3), "kind": kind}}
		assert(game.pickup(actor, 7))
		assert(is_equal_approx(float(actor.get(field)), limit))
		if kind == 2:
			assert(is_equal_approx(game.loot[7].amount, 39.5), "Fractional armor is conserved")
		else:
			assert(not game.loot.has(7))
	actor.reserve = 300
	actor.medkits = 0
	game.loot = {7: {"p": Vector3(0, 0.1, 18.3), "kind": 0}, 8: {"p": Vector3(0.8, 0.1, 18.0), "kind": 1}}
	assert(game.supply_target(actor).id == 8, "Full nearby ammo does not hide usable medicine")
	actor.pitch = -0.45
	other.position = Vector3(10, 0.02, 20)
	game._process(0.016)
	assert("MEDKIT" in game.ui.prompt.text and game.world.highlighted_supply == 8)
	assert(game.world.loot_nodes[8].material_override.emission_enabled)
	assert(game.world.loot_nodes[8].position.distance_to(game.loot[8].p + Vector3.UP * 0.35) < 0.001, "Reused IDs update the visible world position")
	assert(game.world.loot_nodes[8].get_meta("supply_kind") == 1, "Reused IDs update the visible type")
	var proxy: MeshInstance3D = game.world.loot_nodes[8]
	var shell: Node3D = proxy.get_node("SupplyCaseVisual")
	var highlighted_shell := false
	for part in shell.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			if part.get_active_material(surface) == proxy.material_override:
				highlighted_shell = true
	assert(highlighted_shell, "The visible case must share category changes and highlight with its interaction proxy")
	assert(shell.scale.is_equal_approx(proxy.mesh.size), "Detailed cases preserve the pickup footprint")
	if "--capture-supplies" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/supply-prompt.png")
	actor.medkits = 5
	game._process(0.016)
	assert(game.supply_target(actor).id == 7 and "INVENTORY FULL" in game.ui.prompt.text)
	var wall = game.world.block(Vector3(0, 1.5, 19.2), Vector3(4, 3, 0.2), "465a61")
	await sync()
	assert(game.supply_target(actor).is_empty() and not game.pickup(actor, 8), "Cannot collect through a wall")
	wall.queue_free()
	await sync()
	actor.position.z = 25
	assert(not game.pickup(actor, 8), "Explicit target still obeys distance")
	actor.position.z = 20
	actor.reserve = 200
	game.loot[8].kind = 0
	var cmd: Dictionary = game.local_command(actor)
	cmd.seq = 42
	cmd.loot = true
	assert(game.receive_actions(actor, game.match_id, cmd, 8))
	assert(actor.reserve == 245 and game.loot.has(7) and not game.loot.has(8), "Reliable request picks the highlighted ID, not a different nearer item")
	assert(not game.receive_actions(actor, game.match_id, cmd, 7) and actor.reserve == 245)
	cmd.seq = 43
	assert(not game.receive_actions(actor, game.match_id, cmd, "7"))
	assert(not game.receive_actions(actor, game.match_id, cmd, 7.5))
	assert(game.receive_actions(actor, game.match_id, cmd, -1) and actor.reserve == 245, "No target means no network pickup")
	cmd.seq = 44
	assert(not game.receive_actions(actor, "old-round", cmd, 7))
	actor.alive = false
	assert(not game.pickup(actor, 7))
	actor.alive = true
	game.phase = "finished"
	assert(not game.pickup(actor, 7))
	print("SUPPLY_RULES_PASS full=preserved partial=conserved competition=ok armor_fraction=ok usable_priority=ok hud=ok highlight=ok wall=ok range=ok explicit_target=ok replay=ok round=ok dead=ok")
	game.queue_free()
	await process_frame
	quit()
