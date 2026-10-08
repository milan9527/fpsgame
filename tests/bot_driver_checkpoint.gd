extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory := OS.get_environment("CHECKPOINT_TEST_ROOT")
	assert(not directory.is_empty())
	# Isolate save/restore driving from the changing excavated terrain.
	# Keep this collision-only test road alive across world reconstruction.
	var test_road := StaticBody3D.new()
	test_road.collision_layer = 1
	var road_shape := CollisionShape3D.new()
	var road_box := BoxShape3D.new()
	road_box.size = Vector3(44, 0.2, 44)
	road_shape.shape = road_box
	test_road.add_child(road_shape)
	test_road.position = Vector3(17, -0.1, -17)
	root.add_child(test_road)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.checkpoint.path = directory.path_join("bot-driving.dat")
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for scenario in ["solo", "duo", "solo_turn", "duo_turn", "duo_bots", "duo_bots_turn"]:
		var turning: bool = scenario.ends_with("_turn")
		var bot_passenger: bool = scenario.begins_with("duo_bots")
		var mode := "solo" if scenario.begins_with("solo") else "duo"
		var driver_id := -2 if bot_passenger else -1
		var passenger_id := -3 if bot_passenger else 1
		game.start_solo(mode)
		game.elapsed = 30
		for actor in game.actors.values():
			actor.position = Vector3(90, 0.1, 90 + actor.actor_id)
		var bot = game.actors[driver_id]
		var passenger = game.actors[passenger_id]
		bot.position = Vector3(-1.65, 0.04, 0.1)
		passenger.position = Vector3(1.65, 0.04, 0.1)
		var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
		await physics_frame
		await physics_frame
		for _i in range(5):
			car.simulate(1.0 / 60)
		# A standing passenger beside the front wheel is a real route obstacle.
		# Board first so the test reaches the intended moving save/restore state.
		assert(car.seats.enter(passenger, 1))
		bot.navigator.driver.approach(game, bot, Vector3(35, 0, -5) if turning else Vector3(0, 0, -35), 1, true)
		assert(bot.is_seated())
		for _i in range(150 if turning else 75):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
		assert(car.speed > (5 if turning else 9) and bot.navigator.driver.destination.is_finite())
		if turning:
			assert(absf(car.rotation.y) > 0.2 and absf(car.steering) > 0.1)
			assert(not bot.navigator.driver.route.is_empty())
		var saved_speed: float = car.speed
		var saved_heading: float = car.rotation.y
		var saved_steering: float = car.steering
		var saved_position: Vector3 = car.position
		var saved_fuel: float = car.fuel
		var saved_epoch: int = car.seats.epoch
		var car_id: int = car.vehicle_id
		assert(game.suspend_solo())
		assert(game.resume_solo() and paused)
		car = game.vehicle_fleet.vehicles[car_id]
		bot = game.actors[driver_id]
		passenger = game.actors[passenger_id]
		assert(bot.is_bot and bot.is_seated() and passenger.is_seated())
		if bot_passenger:
			assert(passenger.is_bot and game.teams.friendly(bot.actor_id, passenger.actor_id))
		assert(car.speed == saved_speed and car.position.is_equal_approx(saved_position) and car.fuel == saved_fuel)
		assert(car.throttle == 0 and car.seats.epoch == saved_epoch + 1)
		assert(car.steering == saved_steering and bot.navigator.driver.route.is_empty())
		assert(not bot.navigator.driver.destination.is_finite(), "Temporary route must not survive as stale driving intent")
		assert(not car.command(bot.actor_id, 0, 1, 0, false, saved_epoch))
		paused = false
		await physics_frame
		await physics_frame
		var previous_speed: float = car.speed
		var previous_steering: float = absf(car.steering)
		for _i in range(120):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			if bot_passenger:
				game.bot_input(passenger, 1.0 / 60)
			car.simulate(1.0 / 60)
			assert(car.speed <= previous_speed + 0.01, "Restored bot must brake without accelerating")
			previous_speed = car.speed
			assert(absf(car.steering) <= previous_steering + 0.0001 and car.steer_input == 0)
			previous_steering = absf(car.steering)
			assert(absf(wrapf(car.rotation.y - saved_heading, -PI, PI)) < (0.15 if turning else 0.01),
				"Missing route must not create a synthetic turn while braking")
			if not bot.is_seated():
				break
		assert(not bot.is_seated() and bot.collision_mask == 7 and car.driver_id == 0)
		assert(absf(car.speed) < 0.1)
		if bot_passenger:
			assert(not passenger.is_seated() and passenger.collision_mask == 7 and passenger.navigator.driver.cooldown > 0)
		else:
			assert(passenger.is_seated() and car.seats.occupant(1) == passenger)
		assert(car.position.distance_to(saved_position) < saved_speed * saved_speed / (2 * car.BRAKING) + 1,
			"Restore must stop within the physical braking distance plus integration tolerance")
		assert(bot.health == 100 and passenger.health == 100 and car.health == car.MAX_HEALTH)
		assert(bot.navigator.driver.cooldown > 0)
		print("CHECKPOINT_SCENARIO_OK ", scenario, " saved_steering=", saved_steering,
			" heading_change=", absf(wrapf(car.rotation.y - saved_heading, -PI, PI)),
			" stopping_travel=", car.position.distance_to(saved_position))
		game.local_recorded_id = game.match_id
		game.leave()
	print("BOT_DRIVER_CHECKPOINT_PASS solo=ok duo=ok actual_driving=ok disk_restore=ok stale_epoch=ok no_acceleration=ok heading=ok safe_exit=ok passenger=ok turning_restore=ok steering_decay=ok bot_passenger_restore=ok")
	game.request_quit()
