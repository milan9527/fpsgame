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
	# Isolate patrol choice from the end-of-tick inventory transfer.
	game.phase = "finished"
	game.zone_state = {}
	game.zone_center = Vector2.ZERO
	game.zone = 30
	var actor = game.actors[-1]
	for other in game.actors.values():
		other.alive = other == actor
	actor.position = Vector3.ZERO
	actor.health = 100
	actor.ammo = 15
	game.loot.clear()
	# Include equal-distance candidates, the strict 35m boundary, zone
	# exclusion, and a type that bots do not seek.
	for kind in range(6):
		for point in [Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 35, 0), Vector3(24, 0, 0)]:
			game.loot[game.loot.size()] = {"kind": kind, "p": point}
	game.loot[game.loot.size()] = {"kind": 3, "p": Vector3(1, 0, 0)}
	for i in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	assert(game.world.navigation_ready())
	var cases := 0
	for reserve in [44, 45, 46]:
		for medkits in [0, 1]:
			for armor in [24, 25, 26]:
				for smokes in [0, 1]:
					actor.reserve = reserve
					actor.medkits = medkits
					actor.armor = armor
					actor.smokes = smokes
					actor.target_id = 0
					actor.bot_think = 10
					actor.bot_memory_left = 0
					actor.bot_patrol_left = 0
					actor.reload_left = 0
					var oracle := RandomNumberGenerator.new()
					oracle.seed = 391 + cases
					game.rng.seed = oracle.seed
					oracle.randf_range(4, 8)
					var angle := oracle.randf() * TAU
					var radius := sqrt(oracle.randf()) * maxf(4, game.zone - 12)
					var expected := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
					# Original full-scan selection, independent of the optimized guard.
					var nearest := 35.0
					for supply in game.loot.values():
						if Vector2(supply.p.x, supply.p.z).distance_to(game.zone_center) > maxf(4, game.zone - 7):
							continue
						var distance: float = actor.position.distance_to(supply.p)
						var wanted: bool = (supply.kind == 0 and reserve < 45) or (supply.kind == 1 and medkits == 0) or (supply.kind == 2 and armor < 25) or (supply.kind == 4 and smokes == 0 and medkits > 0)
						if wanted and distance < nearest:
							nearest = distance
							expected = supply.p
					game.bot_input(actor, 1.0 / 60)
					assert(actor.bot_destination == expected, "Patrol selection changed in case %d" % cases)
					cases += 1
	print("BOT_PATROL_SUPPLY_RULES_PASS cases=", cases)
	game.request_quit()
