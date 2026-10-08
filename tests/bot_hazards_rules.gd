extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var hazards_script = load("res://scripts/bot_hazards.gd")
	var clearance_probe = hazards_script.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44820260929
	for sample in range(2000):
		var at := Vector3(rng.randf_range(-500, 500), rng.randf_range(-5, 5), rng.randf_range(-500, 500))
		var threats: Array = []
		for threat_index in range(sample % 5):
			threats.append(at + Vector3(rng.randf_range(-14, 14), rng.randf_range(-2, 2), rng.randf_range(-14, 14)))
		assert(clearance_probe.clearance(at, threats) == reference_clearance(at, threats))
	for reach in [0.0, 0.499999, 0.5, 8.999999, 9.0, 10.0, 10.000001, INF, NAN]:
		var threats: Array = [Vector3(reach, 1.2, 0)]
		assert(clearance_probe.clearance(Vector3.ZERO, threats) == reference_clearance(Vector3.ZERO, threats))
	print("HAZARD_CLEARANCE_EQUIVALENCE_PASS randomized=2000 boundaries=9")
	assert(hazards_script.search_offsets.size() == 24)
	for sample in range(100):
		var origin := Vector3(sample * 0.73 - 36, sample * 0.013, sample * -1.17 + 60)
		var offset_index := 0
		for radius in [6.0, 10.0]:
			for index in range(12):
				var angle := index * TAU / 12
				var original: Vector3 = origin + Vector3(cos(angle), 0, sin(angle)) * radius
				assert(original == origin + hazards_script.search_offsets[offset_index], "Cached candidates retain exact positions and order")
				offset_index += 1
	print("HAZARD_CANDIDATE_EQUIVALENCE_PASS positions=2400")
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
	for scan in range(3):
		assert(hazard.select(game, actor, 1) == escape, "Repeated scans retain the same route")
		assert(hazard.tracked == [100, 101], "Scratch buffers must not erase tracked IDs")
	# Force the same search after the candidate list has been sorted. Reused
	# dictionaries must not alias another slot or retain a previous score.
	var pool_size: int = hazard.candidate_pool.size()
	for search in range(3):
		hazard.point = Vector3.INF
		assert(hazard.select(game, actor, 1) == escape, "Rebuilt searches retain the same route")
		assert(hazard.candidate_pool.size() == pool_size, "Identical searches reuse candidate storage")
		for index in range(hazard.candidates.size()):
			for other in range(index):
				assert(not is_same(hazard.candidates[index], hazard.candidates[other]), "Candidate slots must be distinct")
	second.kind = 1
	assert(hazard.select(game, actor, 1).is_finite())
	assert(hazard.tracked == [100] and not hazard.planned.has(101), "Removed threats cannot linger in reused buffers")
	second.kind = 0
	escape = hazard.select(game, actor, 1)
	assert(escape.is_finite() and hazard.tracked == [100, 101], "Threat buffers can grow again after shrinking")
	actor.navigator.utilities.smoke_hold = 8
	actor.navigator.goal = Vector3(0, 0, -20)
	actor.navigator.repath_left = 10
	actor.crouch = true
	actor.aiming = true
	actor.health = 30
	actor.heal()
	game.bot_input(actor, 1.0 / 60)
	assert(actor.sprint and not actor.shooting and not actor.aiming and not actor.crouch)
	assert(actor.heal_left == 0 and actor.medkits == 2, "Bots cancel treatment with the same no-consumption rule as players")
	actor.health = 100
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
	assert(hazard.tracked.is_empty() and hazard.planned.is_empty(), "No-grenade scans release all cached threats")
	print("BOT_HAZARDS_RULES_PASS smoke_ignored=ok detection_range=ok blast_cover=ok navigation=ok zone_limit=ok hold_interrupt=ok physical_escape=ok damage=zero cleanup=ok")
	game.request_quit()

func reference_clearance(at: Vector3, threats: Array) -> float:
	var margin_squared := INF
	var sample := at + Vector3.UP * 1.2
	var nearest := Vector3.INF
	for threat in threats:
		var distance_squared := sample.distance_squared_to(threat)
		if distance_squared < margin_squared:
			margin_squared = distance_squared
			nearest = threat
	return sample.distance_to(nearest) if margin_squared < INF else INF
