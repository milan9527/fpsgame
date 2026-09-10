extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://../artifacts/" + path + ".png")
	return image

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.elapsed = 20
	for actor in game.actors.values():
		actor.position = Vector3(100, 0.02, 100)
	var player = game.actors[1]
	var target = game.actors[-1]
	player.position = Vector3(0, 0.02, 14)
	player.yaw = 0
	target.position = Vector3(0, 0.02, -14)
	player.smokes = 2
	var item := {"kind": 4, "amount": 2.0}
	assert(game.SupplyRules.transfer(player, item) == 1 and player.smokes == 3 and item.amount == 1)
	var cmd: Dictionary = game.local_command(player)
	cmd.smoke_throw = true
	assert(game.receive_actions(player, game.match_id, cmd))
	assert(player.smokes == 2 and player.grenades == 2)
	assert(not game.receive_actions(player, game.match_id, cmd) and player.smokes == 2)
	var grenade = game.grenades.values()[0]
	assert(grenade.kind == 1 and grenade.pack().kind == 1)
	grenade.freeze = true
	grenade.position = Vector3.ZERO
	var health: float = player.health
	game.detonate_grenade(grenade.grenade_id)
	assert(game.smoke_clouds.size() == 1 and player.health == health)
	assert(not game.smoke_blocks(player.eye_position(), target.eye_position()))
	game.advance_grenades(2)
	assert(game.smoke_blocks(player.eye_position(), target.eye_position()))
	assert(game.SmokeRules.optical_depth(Vector3(0, 2, 0), Vector3(0, 2, 2), Vector3(0, 2, 0), 2) == 2)
	assert(not game.smoke_blocks(Vector3(10, 2, 10), Vector3(10, 2, -10)))
	await physics_frame
	await physics_frame
	assert(not game.visible_target(player, target), "Smoke hides target from bot vision")
	var hit: Dictionary = game.trace_shot(player, player.eye_position(), Vector3.FORWARD, 0)
	assert(hit.get("collider") == target, "Smoke does not stop bullets")
	game.update_smoke_visuals()
	assert(game.smoke_visuals.size() == 1)
	if "--capture-smoke" in OS.get_cmdline_user_args():
		player.render_frame(0, false, true, false)
		await capture("smoke-outside")
		player.position = Vector3(0, 0.02, 0)
		player.render_frame(0, false, true, false)
		await capture("smoke-inside")
		player.position = Vector3(0, 0.02, 14)
		player.render_frame(0, false, true, false)
		game.world.block(Vector3(0, 2, 9), Vector3(10, 4, 0.3), "c94c39")
		await capture("smoke-wall")
	assert(game.receive_drop(player, game.match_id, cmd.seq + 1, 4, 1) and player.smokes == 1)
	player.alive = false
	game.drop_inventory(player)
	assert(player.smokes == 0)
	var smoke_stock := 0.0
	for supply in game.loot.values():
		if supply.kind == 4 and supply.has("drop_slot"):
			smoke_stock += supply.amount
	assert(smoke_stock == 2, "Dropped and eliminated smoke inventory is conserved")
	game.advance_grenades(18)
	game.update_smoke_visuals()
	assert(game.smoke_clouds.is_empty() and game.smoke_visuals.is_empty())
	game.network_round_id = "new-round"
	game.smoke_snapshot("old-round", [{"id": 1, "p": Vector3.ZERO, "age": 2.0}], [1])
	assert(game.smoke_clouds.is_empty(), "Stale round cannot restore a cloud")
	game.clear_grenades()
	print("SMOKE_GRENADE_RULES_PASS inventory=ok reliable_once=ok no_damage=ok growth=ok vision=ok bullet_pass=ok rendering_state=ok drop_death=ok expiry=ok stale_round=ok")
	game.queue_free()
	await process_frame
	quit()
