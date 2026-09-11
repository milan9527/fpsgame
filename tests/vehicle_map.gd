extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	for actor in game.actors.values():
		actor.is_bot = false
	await sync_physics()
	game._physics_process(1.0 / 60)
	assert(game.vehicle_fleet.map_spawned and game.vehicle_fleet.vehicles.size() == 4)
	assert(game.vehicle_fleet.spawn_map(game) == 0)
	for _step in range(15):
		game._physics_process(1.0 / 60)
	for car in game.vehicle_fleet.vehicles.values():
		assert(car.grounded and car.position.y < 0.1 and car.health == car.MAX_HEALTH)
		assert(car.can_rotate(car.rotation.y))
		assert(car.fuel >= 60 and car.fuel <= 84)
		var actor = game.actors[1]
		actor.position = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.86
		assert(car.seats.enter(actor, 0))
		if car.vehicle_id == 1 and DisplayServer.get_name() != "headless":
			game._process(0.016)
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://../artifacts/vehicle-map-driving.png") == OK)
		assert(car.seats.exit(actor))
	game.vehicle_fleet.clear()
	var candidate: Dictionary = game.vehicle_fleet.MAP_SPAWNS[0]
	game.actors[1].position = candidate.p
	var raised = game.world.block(game.vehicle_fleet.MAP_SPAWNS[1].p + Vector3.UP * 0.75, Vector3(4, 1.5, 5), "465a61")
	await sync_physics()
	assert(game.vehicle_fleet.spawn_map(game) == 2, "Occupied points and raised obstacles must be skipped")
	raised.queue_free()
	game.vehicle_fleet.clear()
	game.actors[1].position = Vector3(60, 0, 60)
	await sync_physics()
	# Exercise all four boundaries with the actual world and swept vehicle body.
	for heading in [0.0, PI / 2, PI, -PI / 2]:
		var forward := -Basis(Vector3.UP, heading).z
		var lane := Basis(Vector3.UP, heading).x * 4.5
		var car = game.vehicle_fleet.spawn(game, forward * 108 + lane + Vector3.UP * 0.04, heading)
		await sync_physics()
		for _step in range(5):
			car.simulate(1.0 / 60)
		car.set_driver(777)
		for step in range(180):
			assert(car.command(777, step, 1, 0, false))
			car.simulate(1.0 / 60)
			await physics_frame
		var extent: Vector2 = car.horizontal_extent(car.rotation.y)
		print("ARENA_EDGE heading=", heading, " position=", car.position, " speed=", car.speed)
		assert(absf(car.position.x) + extent.x <= 115.001 and absf(car.position.z) + extent.y <= 115.001)
		assert(car.position.dot(forward) > 113.0 and absf(car.speed) < 0.01)
		assert(car.health == car.MAX_HEALTH, "Arena restriction is not an invisible damaging wall")
		assert(not car.can_rotate(heading + 0.5))
		game.vehicle_fleet.clear()
	# A restored empty legacy world must not gain vehicles on its next tick.
	game.vehicle_fleet.map_spawned = true
	game._physics_process(1.0 / 60)
	assert(game.vehicle_fleet.vehicles.is_empty())
	game.local_recorded_id = game.match_id
	game.start_solo("duo")
	await sync_physics()
	game._physics_process(1.0 / 60)
	assert(game.vehicle_fleet.vehicles.size() == 4)
	game.local_recorded_id = game.match_id
	game.leave()
	assert(game.vehicle_fleet.vehicles.is_empty())
	game.queue_free()
	await process_frame
	print("VEHICLE_MAP_PASS four_spawns=ok floor=ok doors=ok occupancy=ok no_roof_spawn=ok idempotent=ok four_boundaries=ok no_boundary_damage=ok legacy_world=ok duo_restart=ok cleanup=ok")
	quit()
