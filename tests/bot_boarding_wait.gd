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
	for scenario in ["board", "leave", "timeout"]:
		game.start_solo("duo")
		for actor in game.actors.values():
			actor.position = Vector3(95, 0.1, 95 + actor.actor_id)
		var bot = game.actors[-1]
		var teammate = game.actors[1]
		assert(game.teams.friendly(bot.actor_id, teammate.actor_id))
		bot.position = Vector3(-1.65, 0.04, 0.1)
		teammate.position = Vector3(1.65, 0.04, 0.1)
		game.zone = 5
		game.zone_center = Vector2(0, -35)
		game.zone_state = {}
		var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
		await physics_frame
		await physics_frame
		for _step in range(5):
			car.simulate(1.0 / 60)
		game.bot_input(bot, 1.0 / 60)
		assert(bot.is_seated())
		var parked: Vector3 = car.position
		for _step in range(60):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
			assert(absf(car.speed) < 0.01 and car.position.distance_to(parked) < 0.03)
		assert(car.handbrake and car.throttle == 0 and not bot.navigator.driver.boarding_departed)
		assert(bot.navigator.driver.trip_time < 0.05, "Boarding wait must not consume the driving timeout")
		if scenario == "board":
			assert(car.seats.enter(teammate, 1))
		elif scenario == "leave":
			teammate.position.x += 8
		for _step in range(150 if scenario == "timeout" else 20):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
		assert(car.speed > 1 and bot.navigator.driver.boarding_departed)
		assert(car.health == car.MAX_HEALTH)
		if scenario == "board":
			assert(teammate.is_seated() and car.seats.occupant(1) == teammate)
		else:
			assert(not teammate.is_seated(), "Waiting must never force a teammate into a seat")
		print("BOT_BOARDING_CASE_OK ", scenario)
		game.local_recorded_id = game.match_id
		game.leave()
	print("BOT_BOARDING_WAIT_PASS nearby_ally=wait boarding=depart leaving=depart timeout=depart passenger=secured")
	game.request_quit()
