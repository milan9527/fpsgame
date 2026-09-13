extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for scenario in ["ride", "blocked_exit", "enemy", "combat", "healing", "no_fuel", "moving", "blocked_door"]:
		game.start_solo("duo")
		for actor in game.actors.values():
			actor.position = Vector3(95, 0.1, 95 + actor.actor_id)
		var bot = game.actors[-1]
		var driver = game.actors[-2 if scenario == "enemy" else 1]
		bot.position = Vector3(1.65, 0.04, 0.1)
		driver.position = Vector3(-1.65, 0.04, 0.1)
		var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
		await physics_frame
		await physics_frame
		for _step in range(5):
			car.simulate(1.0 / 60)
		assert(car.seats.enter(driver, 0))
		bot.bot_think = 10
		bot.target_id = 0
		if scenario == "enemy":
			assert(not game.teams.friendly(driver.actor_id, bot.actor_id))
		elif scenario == "combat":
			bot.bot_memory_left = 3
		elif scenario == "healing":
			bot.health = 60
			bot.heal()
			assert(bot.heal_left > 0)
		elif scenario == "no_fuel":
			car.fuel = 0
		elif scenario == "moving":
			car.speed = 1
		elif scenario == "blocked_door":
			bot.position.x = 3.5
			game.world.block(Vector3(2.7, 1.5, 0.1), Vector3(0.2, 3, 3), "657477")
			await physics_frame
		game.bot_input(bot, 1.0 / 60)
		if scenario not in ["ride", "blocked_exit"]:
			assert(not bot.is_seated(), "Unsafe or unavailable teammate rides must be rejected: " + scenario)
		else:
			assert(bot.is_seated() and car.seats.occupant(1) == bot)
			for _step in range(100):
				await physics_frame
				car.command(driver.actor_id, car.input_sequence + 1, 1, 0, false, car.seats.epoch)
				game.bot_input(bot, 1.0 / 60)
				car.simulate(1.0 / 60)
				assert(bot.is_seated())
			assert(car.speed > 5 and car.position.z < -5)
			car.seats.release(driver, Vector3(-5, 0.04, car.position.z))
			game.bot_input(bot, 1.0 / 60)
			assert(bot.is_seated(), "A passenger must not jump out of a moving vehicle when the driver leaves")
			if scenario == "blocked_exit":
				for _step in range(180):
					await physics_frame
					car.simulate(1.0 / 60)
					if absf(car.speed) < 0.1:
						break
				assert(absf(car.speed) < 0.1)
				var barriers: Array = []
				for point in car.seats.EXIT_POINTS:
					barriers.append(game.world.block(car.to_global(point) + Vector3.UP, Vector3(0.6, 2, 0.6), "657477"))
				await physics_frame
				await physics_frame
				for _step in range(30):
					await physics_frame
					game.bot_input(bot, 1.0 / 60)
					car.simulate(1.0 / 60)
					assert(bot.is_seated() and bot.position.distance_to(car.to_global(car.seats.ANCHORS[1])) < 0.01,
						"Blocked exits must keep the bot secured at the seat")
				for barrier in barriers:
					game.world.remove_child(barrier)
					barrier.queue_free()
				await physics_frame
				await physics_frame
			for _step in range(180):
				await physics_frame
				car.simulate(1.0 / 60)
				game.bot_input(bot, 1.0 / 60)
				if not bot.is_seated():
					break
			assert(not bot.is_seated() and absf(car.speed) < 0.1)
			assert(bot.health == 100 and bot.navigator.driver.cooldown > 7)
		print("BOT_RIDER_CASE_OK ", scenario)
		game.local_recorded_id = game.match_id
		game.leave()
	# Both seats are acquired through normal AI in a server-assigned bot pair.
	game.start_solo("duo")
	for actor in game.actors.values():
		actor.position = Vector3(95, 0.1, 95 + actor.actor_id)
	var driver = game.actors[-2]
	var passenger = game.actors[-3]
	assert(driver.is_bot and passenger.is_bot and game.teams.friendly(driver.actor_id, passenger.actor_id))
	driver.position = Vector3(-1.65, 0.04, 0.1)
	passenger.position = Vector3(1.65, 0.04, 0.1)
	game.zone = 5
	game.zone_center = Vector2(0, -35)
	game.zone_state = {}
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await physics_frame
	await physics_frame
	for _step in range(5):
		car.simulate(1.0 / 60)
	game.bot_input(driver, 1.0 / 60)
	assert(car.seats.occupant(0) == driver)
	game.bot_input(passenger, 1.0 / 60)
	assert(car.seats.occupant(1) == passenger)
	var moving := false
	for _step in range(900):
		await physics_frame
		if driver.is_seated():
			game.bot_input(driver, 1.0 / 60)
		game.bot_input(passenger, 1.0 / 60)
		car.simulate(1.0 / 60)
		moving = moving or car.speed > 5
		if not driver.is_seated() and not passenger.is_seated():
			break
	assert(moving and car.position.z < -25 and absf(car.speed) < 0.1)
	assert(not driver.is_seated() and not passenger.is_seated())
	assert(driver.health == 100 and passenger.health == 100)
	game.local_recorded_id = game.match_id
	game.leave()
	print("BOT_PASSENGER_PASS normal_ai=board moving=ride driver_departure=wait_for_stop safe_exit=ok blocked_exit=wait_and_retry enemy=reject combat=priority healing=priority fuel=required moving_entry=reject blocked_door=reject bot_pair=drive_and_exit")
	game.request_quit()
