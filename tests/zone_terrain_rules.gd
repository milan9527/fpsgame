extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	assert(game.world.accepts_zone_center(Vector2.ZERO), "Fallback intersection must be clear before nav synchronization")
	assert(not game.world.accepts_zone_center(Vector2(-42, -35)), "Building footprint is excluded")
	for tick in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	assert(game.world.navigation_ready())
	var plan = load("res://scripts/zone_rules.gd").new()
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask = 1
	# Check standing clearance across the final disk, above the ground floor.
	var disk := CylinderShape3D.new()
	disk.radius = 4.4
	disk.height = 1.6
	query.shape = disk
	for seed_value in range(100):
		plan.reset(seed_value, game.world.accepts_zone_center)
		var prior := Vector2.ZERO
		var prior_radius := 110.0
		for i in range(6):
			var center: Vector2 = plan.centers[i + 1]
			assert(game.world.accepts_zone_center(center))
			assert(prior.distance_to(center) + plan.RADII[i] <= prior_radius + 0.001)
			var at := Vector3(center.x, 0.1, center.y)
			var projected: Vector3 = game.world.navigation_point(at)
			assert(projected.distance_to(at) < 0.7, "Center stays on ground navigation")
			var path := NavigationServer3D.map_get_path(game.get_world_3d().navigation_map, Vector3.ZERO, projected, true)
			assert(not path.is_empty() and path[-1].distance_to(projected) < 0.1, "Center connects to main ground component")
			query.transform.origin = Vector3(center.x, 1.1, center.y)
			assert(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Final circle has standing clearance against actual static colliders")
			prior = center
			prior_radius = plan.RADII[i]
	var saved: Array = plan.centers.duplicate()
	plan.reset(99, game.world.accepts_zone_center)
	assert(saved == plan.centers, "Terrain rejection preserves deterministic seeds")
	plan.reset(1, func(_center): return false)
	assert(plan.centers.all(func(center): return center == Vector2.ZERO), "Rejection budget has finite stable fallback")
	var bot = game.actors[-1]
	for actor in game.actors.values():
		actor.position = Vector3(-100, 0.02, -100)
	bot.position = Vector3(0, 0.02, 60)
	bot.bot_think = 100
	bot.bot_destination = Vector3(0, 0, 65)
	bot.bot_patrol_left = 100
	bot.navigator.finished = false
	game.zone = 110
	game.zone_center = Vector2.ZERO
	game.zone_state = {"next_center": Vector2.ZERO, "next_radius": 20.0, "moving": false, "remaining": 40.0}
	game.bot_input(bot, 0.016)
	assert(not bot.sprint and bot.navigator.goal == Vector3(0, 0, 65), "Long hold permits normal patrol")
	bot.navigator.repath_left = 0
	game.zone_state.remaining = 10.0
	game.bot_input(bot, 0.016)
	assert(bot.sprint and bot.navigator.goal == Vector3(0, 0, 13), "Upcoming shrink triggers early rotation while currently safe")
	bot.navigator.repath_left = 0
	game.zone_state.remaining = 30.0
	game.zone_state.moving = true
	game.bot_input(bot, 0.016)
	assert(bot.sprint and bot.navigator.goal == Vector3(0, 0, 13), "Moving phase triggers rotation immediately")
	print("ZONE_TERRAIN_RULES_PASS seeds=100 centers=600 actual_collision=ok navigation_connectivity=ok deterministic=ok fallback=ok early_rotation=ok")
	game.queue_free()
	await process_frame
	quit()
