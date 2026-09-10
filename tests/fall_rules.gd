extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func land(game, actor) -> float:
	var peak := 0.0
	for tick in range(240):
		await physics_frame
		actor.simulate(1.0 / 60)
		peak = maxf(peak, actor.landing_speed)
		game.apply_landing(actor)
		if actor.grounded:
			return peak
	assert(false, "Actor did not reach the floor")
	return -1

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
	assert(game.FallRules.damage_for_speed(12) == 0)
	assert(game.FallRules.damage_for_speed(NAN) == 0)
	assert(game.FallRules.damage_for_speed(INF) == 0)
	var low = game.spawn_actor(201, "LOW", false, Vector3(0, 1, 20))
	low.armor = 100
	var low_speed: float = await land(game, low)
	assert(low_speed < 12 and low.health == 100 and low.armor == 100)
	low.jump_requested = true
	low.simulate(1.0 / 60)
	assert(not low.grounded)
	var jump_speed: float = await land(game, low)
	assert(jump_speed < 12 and low.health == 100, "Ordinary jumps are safe")
	low.position = Vector3(90, 0.02, 90)
	var medium = game.spawn_actor(202, "ROOF", false, Vector3(0, 4.5, 20))
	medium.armor = 100
	medium.heal_left = 3
	var medium_speed: float = await land(game, medium)
	assert(medium_speed > 12 and medium.health < 100 and medium.health > 40)
	assert(medium.armor == 100 and medium.heal_left == 0, "Landing bypasses armor and interrupts medicine")
	var remaining: float = medium.health
	game.apply_landing(medium)
	assert(medium.health == remaining, "Impact is consumed once")
	medium.position = Vector3(80, 0.02, 80)
	var fatal = game.spawn_actor(203, "HIGH", false, Vector3(0, 10, 20))
	fatal.armor = 100
	await land(game, fatal)
	assert(not fatal.alive and fatal.rank > 0 and fatal.armor == 0, "Lethal fall eliminates and transfers armor to death loot")
	assert(game.events[-1] == "FALL  >  HIGH")
	assert(game.actors[1].kills == 0, "Fall is not credited as a weapon kill")
	assert(game.loot.values().any(func(item): return item.get("drop_slot", -1) == 2 and item.amount == 100))
	var client = game.spawn_actor(204, "CLIENT", false, Vector3(0, 0.02, 40))
	client.landing_speed = 30
	game.online = true
	game.dedicated = false
	game.apply_landing(client)
	assert(client.health == 100, "Client prediction never applies health damage")
	game.online = false
	game.elapsed = 2
	game.apply_landing(client)
	assert(client.health == 100, "Opening protection also covers landings")
	game.elapsed = 20
	game.phase = "lobby"
	client.landing_speed = 30
	game.apply_landing(client)
	assert(client.health == 100)
	game.phase = "live"
	var ramp = game.world.block(Vector3(-20, 1, 20), Vector3(10, 0.4, 10), "657477")
	ramp.rotation.x = deg_to_rad(18)
	var slope = game.spawn_actor(205, "SLOPE", false, Vector3(-20, 2.5, 20))
	await land(game, slope)
	assert(slope.health == 100, "Short sloped landings remain safe")
	print("FALL_RULES_PASS real_gravity=ok normal_jump=ok roof_damage=ok armor_bypass=ok heal_interrupt=ok lethal_loot_rank=ok once=ok client_no_damage=ok protection=ok slope=ok")
	game.queue_free()
	await process_frame
	quit()
