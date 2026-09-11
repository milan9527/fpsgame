extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory := "user://qa-vehicle-checkpoint-%d" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.checkpoint.path = directory.path_join("operation.dat")
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for mode in ["solo", "duo"]:
		game.start_solo(mode)
		game.elapsed = 30
		var driver = game.actors[1]
		var passenger = game.actors[-1]
		driver.position = Vector3(-1.65, 0.04, 0.1)
		passenger.position = Vector3(1.65, 0.04, 0.1)
		var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
		var wreck = game.vehicle_fleet.spawn(game, Vector3(12, 0, 0))
		await physics_frame
		await physics_frame
		for _step in range(5):
			game.vehicle_fleet.step(1.0 / 60, true)
		assert(car.seats.enter(driver, 0) and car.seats.enter(passenger, 1))
		car.fuel = 43.125
		car.take_damage(137)
		car.rotation.y = 0.2
		car.speed = 7
		car.velocity = -car.global_basis.z * 7
		car.steering = 0.1
		car.seats.refresh()
		car.wheel_rigs[0].roll.rotation.x = 1.2
		car.collision_cooldowns["v:2"] = car.collision_time + 0.6
		game.vehicle_fleet.pair_cooldowns["1:2"] = game.vehicle_fleet.simulation_time + 0.6
		wreck.take_damage(1000)
		driver.vehicle_camera.begin(car)
		driver.vehicle_camera.orbit_yaw = 0.7
		driver.vehicle_camera.orbit_pitch = -0.4
		driver.vehicle_camera.distance = 4.5
		if mode == "duo":
			game.damage(passenger, 10000, -2, true)
			assert(passenger.downed and passenger.is_seated())
		var state: Dictionary = game.snapshot_solo()
		assert(state.version == 3 and state.mode == mode and game.checkpoint.validate(state, game.build_info.content_revision))
		var malformed: Array = []
		var bad := state.duplicate(true)
		bad.vehicles.items[0].fuel = NAN
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[0].seats = [1, 1]
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[1].seats = [1, 0]
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[0].seats = [999, 0]
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[0].p += Vector3(5, 0, 0)
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[1].destroyed = false
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.pairs = {"1:999": 0.5}
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.items[0].cooldowns = {"v:2": 50.0}
		malformed.append(bad)
		bad = state.duplicate(true)
		bad.vehicles.next_id = 1
		malformed.append(bad)
		for invalid in malformed:
			assert(not game.checkpoint.validate(invalid, game.build_info.content_revision))
		var epoch: int = car.seats.epoch
		var health: float = driver.health
		var saved_position: Vector3 = car.position
		var round_id: String = game.match_id
		assert(game.suspend_solo())
		assert(not game.running and game.vehicle_fleet.vehicles.is_empty())
		assert(game.resume_solo())
		assert(paused and game.match_id == round_id and game.match_mode == mode)
		assert(game.vehicle_fleet.vehicles.size() == 2 and game.vehicle_fleet.next_id == 3)
		car = game.vehicle_fleet.vehicles[1]
		wreck = game.vehicle_fleet.vehicles[2]
		driver = game.actors[1]
		passenger = game.actors[-1]
		assert(driver.is_seated() and passenger.is_seated() and car.seats.occupant(0) == driver and car.seats.occupant(1) == passenger)
		assert(passenger.downed == (mode == "duo"))
		assert(car.position.is_equal_approx(saved_position) and car.speed == 7 and car.health == 463 and car.fuel == 43.125)
		assert(car.driver_id == 1 and car.throttle == 0 and car.input_sequence == -1 and car.seats.epoch == epoch + 1)
		assert(not car.command(1, 0, 1, 0, false, epoch))
		assert(car.can_rotate(0.3) and driver.health == health and driver.collision_mask == 0)
		assert(wreck.destroyed and wreck.health == 0 and wreck.visual.find_children("*", "MeshInstance3D", true, false)[0].material_override != null)
		assert(is_equal_approx(car.collision_cooldowns["v:2"], 0.6) and is_equal_approx(game.vehicle_fleet.pair_cooldowns["1:2"], 0.6))
		assert(is_equal_approx(car.wheel_rigs[0].roll.rotation.x, 1.2))
		assert(is_equal_approx(driver.vehicle_camera.orbit_yaw, 0.7) and is_equal_approx(driver.vehicle_camera.distance, 4.5))
		paused = false
		await physics_frame
		await physics_frame
		game.vehicle_fleet.step(1.0 / 60, true)
		assert(car.speed < 7 and car.speed > 6, "Restored vehicle brakes until fresh driver input")
		assert(driver.health == health and wreck.health == 0)
		game.local_recorded_id = game.match_id
		game.leave()
	# Old empty-fleet solo snapshots keep their original schema.
	game.start_solo()
	assert(game.snapshot_solo().version == 1)
	game.local_recorded_id = game.match_id
	game.leave()
	game.queue_free()
	await process_frame
	print("VEHICLE_CHECKPOINT_PASS solo=ok duo=ok disk_roundtrip=ok moving_seats=ok wreck_no_damage=ok input_epoch=ok cooldowns=ok camera=ok corruption=ok legacy=ok")
	quit()
