extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory := OS.get_environment("CHECKPOINT_TEST_ROOT")
	assert(not directory.is_empty())
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.checkpoint.path = directory.path_join("bot-driving.dat")
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for mode in ["solo", "duo"]:
		game.start_solo(mode)
		game.elapsed = 30
		for actor in game.actors.values():
			actor.position = Vector3(90, 0.1, 90 + actor.actor_id)
		var bot = game.actors[-1]
		var passenger = game.actors[1]
		bot.position = Vector3(-1.65, 0.04, 0.1)
		passenger.position = Vector3(1.65, 0.04, 0.1)
		var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
		await physics_frame
		await physics_frame
		for _i in range(5):
			car.simulate(1.0 / 60)
		bot.navigator.driver.approach(game, bot, Vector3(0, 0, -35), 1, true)
		assert(bot.is_seated() and car.seats.enter(passenger, 1))
		for _i in range(75):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
		assert(car.speed > 9 and car.throttle > 0 and bot.navigator.driver.destination.is_finite())
		var saved_speed: float = car.speed
		var saved_heading: float = car.rotation.y
		var saved_position: Vector3 = car.position
		var saved_fuel: float = car.fuel
		var saved_epoch: int = car.seats.epoch
		var car_id: int = car.vehicle_id
		assert(game.suspend_solo())
		assert(game.resume_solo() and paused)
		car = game.vehicle_fleet.vehicles[car_id]
		bot = game.actors[-1]
		passenger = game.actors[1]
		assert(bot.is_bot and bot.is_seated() and passenger.is_seated())
		assert(car.speed == saved_speed and car.position.is_equal_approx(saved_position) and car.fuel == saved_fuel)
		assert(car.throttle == 0 and car.seats.epoch == saved_epoch + 1)
		assert(not bot.navigator.driver.destination.is_finite(), "Temporary route must not survive as stale driving intent")
		assert(not car.command(bot.actor_id, 0, 1, 0, false, saved_epoch))
		paused = false
		await physics_frame
		await physics_frame
		var previous_speed: float = car.speed
		for _i in range(120):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
			assert(car.speed <= previous_speed + 0.01, "Restored bot must brake without accelerating")
			previous_speed = car.speed
			assert(absf(wrapf(car.rotation.y - saved_heading, -PI, PI)) < 0.01,
				"Missing route must not create a synthetic turn while braking")
			if not bot.is_seated():
				break
		assert(not bot.is_seated() and bot.collision_mask == 7 and car.driver_id == 0)
		assert(absf(car.speed) < 0.1 and passenger.is_seated() and car.seats.occupant(1) == passenger)
		assert(bot.health == 100 and passenger.health == 100 and car.health == car.MAX_HEALTH)
		assert(bot.navigator.driver.cooldown > 0)
		game.local_recorded_id = game.match_id
		game.leave()
	print("BOT_DRIVER_CHECKPOINT_PASS solo=ok duo=ok actual_driving=ok disk_restore=ok stale_epoch=ok no_acceleration=ok heading=ok safe_exit=ok passenger=ok")
	game.request_quit()
