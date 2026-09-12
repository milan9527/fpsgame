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
	for side in [-1, 1]:
		game.start_solo("duo")
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
		var controller = bot.navigator.driver
		assert(controller.turning_route(car, Vector3(35 * side, 0, -5), bot).is_empty(),
			"Standing player in the swept hull envelope must block departure")
		assert(car.seats.enter(passenger, 1))
		controller.approach(game, bot, Vector3(35 * side, 0, -5), 1, true)
		assert(bot.is_seated() and not controller.route.is_empty(), "Existing passenger must not invalidate route")
		for _frame in range(150):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
		assert(car.speed > 5 and absf(car.rotation.y) > 0.2 and absf(car.steering) > 0.1)
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(10, 4, 0.5)
		collision.shape = box
		wall.add_child(collision)
		game.add_child(wall)
		wall.position = car.position - car.global_basis.z * 6 + Vector3.UP * 2
		wall.rotation.y = car.rotation.y
		await physics_frame
		await physics_frame
		var braked := false
		for _frame in range(180):
			await physics_frame
			game.bot_input(bot, 1.0 / 60)
			car.simulate(1.0 / 60)
			braked = braked or controller.stopping
			assert(car.health == car.MAX_HEALTH and bot.health == 100 and passenger.health == 100)
			if not bot.is_seated():
				break
		assert(braked and not bot.is_seated() and absf(car.speed) < 0.1)
		assert(passenger.is_seated() and car.seats.occupant(1) == passenger)
		assert(wall.to_local(car.position).z > car.BODY_SIZE.z / 2 + 0.25)
		assert(controller.route.is_empty() and controller.cooldown > 0)
		print("TURN_OBSTACLE_SIDE_OK ", side)
		wall.queue_free()
		game.local_recorded_id = game.match_id
		game.leave()
	print("BOT_DRIVER_TURN_OBSTACLE_PASS left=ok right=ok passenger=ok brake=ok no_collision=ok safe_exit=ok")
	game.request_quit()
