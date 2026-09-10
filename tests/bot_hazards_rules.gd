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
	game.elapsed = 20
	game.zone_state = {}
	game.loot.clear()
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 105)
	var actor = game.actors[-1]
	actor.position = Vector3(0, 0.02, 20)
	actor.grenades = 0
	actor.smokes = 0
	actor.health = 100
	actor.armor = 0
	for tick in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	assert(game.world.navigation_ready())
	var hazard = actor.navigator.hazards
	var grenade = game.Grenade.new()
	grenade.grenade_id = 100
	grenade.owner_id = 1
	grenade.kind = 1
	grenade.position = Vector3(0, 0.15, 17)
	game.add_child(grenade)
	game.grenades[100] = grenade
	assert(not hazard.select(game, actor, 1).is_finite(), "Smoke does not cause grenade panic")
	grenade.kind = 0
	grenade.position = Vector3(0, 0.15, -20)
	assert(not hazard.select(game, actor, 1).is_finite(), "No knowledge of distant projectiles")
	grenade.position = Vector3(0, 0.15, 17)
	var wall = game.world.block(Vector3(0, 1.5, 18.5), Vector3(6, 3, 0.4), "657477")
	await physics_frame
	assert(not hazard.select(game, actor, 1).is_finite(), "Fully shielded actors can keep their cover")
	game.world.remove_child(wall)
	wall.queue_free()
	await physics_frame
	assert(hazard.select(game, actor, 1).is_finite())
	var second = game.Grenade.new()
	second.grenade_id = 101
	second.owner_id = 1
	second.position = Vector3(2, 0.15, 17)
	game.add_child(second)
	game.grenades[101] = second
	var escape: Vector3 = hazard.select(game, actor, 1)
	assert(escape.is_finite() and escape.distance_to(grenade.position) > 9)
	assert(escape.distance_to(second.position) > 9 and hazard.tracked.size() == 2 and hazard.planned.has(101), "New threats invalidate a cached route")
	grenade.position += Vector3.RIGHT * 2
	escape = hazard.select(game, actor, 1)
	assert(escape.is_finite() and hazard.planned[100] == grenade.position, "Moving threats invalidate a cached route")
	assert(Vector2(escape.x, escape.z).length() <= game.zone - 1)
	actor.navigator.utilities.smoke_hold = 8
	actor.navigator.goal = Vector3(0, 0, -20)
	actor.navigator.repath_left = 10
	actor.crouch = true
	actor.aiming = true
	game.bot_input(actor, 1.0 / 60)
	assert(actor.sprint and not actor.shooting and not actor.aiming and not actor.crouch)
	assert(actor.navigator.utilities.smoke_hold == 0 and actor.navigator.goal == escape)
	var start: Vector3 = actor.position
	for tick in range(180):
		await physics_frame
		game.bot_input(actor, 1.0 / 60)
		actor.simulate(1.0 / 60)
		game.advance_grenades(1.0 / 60)
		if game.grenades.is_empty():
			break
	assert(game.grenades.is_empty(), "Real grenade detonated")
	assert(actor.alive and actor.health == 100, "Actor physically escaped the blast without invulnerability")
	assert(actor.position.distance_to(start) > 6)
	assert(not hazard.select(game, actor, 1).is_finite(), "Escape state clears after detonation")
	print("BOT_HAZARDS_RULES_PASS smoke_ignored=ok detection_range=ok blast_cover=ok navigation=ok zone_limit=ok hold_interrupt=ok physical_escape=ok damage=zero cleanup=ok")
	game.request_quit()
