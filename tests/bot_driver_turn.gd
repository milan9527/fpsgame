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
	game.start_solo()
	for actor in game.actors.values():
		actor.position = Vector3(90, 0.1, 90 + actor.actor_id)
	var bot = game.actors[-1]
	bot.position = Vector3(-1.65, 0.04, 0.1)
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await physics_frame
	await physics_frame
	for _i in range(5):
		car.simulate(1.0 / 60)
	var controller = bot.navigator.driver
	var goal := Vector3(-35 if "--left" in OS.get_cmdline_user_args() else 35, 0, -5)
	var planned: PackedVector3Array = controller.turning_route(car, goal, bot)
	assert(not planned.is_empty(), "Open turn should have a route")
	assert(controller.turning_route(car, Vector3(0, 0, 35), bot).is_empty(), "Reverse target needs a separate maneuver")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = planned[planned.size() / 2] + Vector3.UP * 2
	await physics_frame
	await physics_frame
	assert(controller.turning_route(car, goal, bot).is_empty(), "Curved hull route must reject an obstruction")
	wall.queue_free()
	await physics_frame
	await physics_frame
	controller.approach(game, bot, goal, 1, true)
	assert(bot.is_seated() and not controller.route.is_empty())
	var maximum_speed := 0.0
	for _frame in range(1500):
		await physics_frame
		controller.drive(bot, 1.0 / 60)
		car.simulate(1.0 / 60)
		maximum_speed = maxf(maximum_speed, car.speed)
		if not bot.is_seated():
			break
	print("TURN_RESULT position=", car.position, " speed=", car.speed, " max=", maximum_speed, " yaw=", car.rotation.y)
	assert(not bot.is_seated(), "Driver must disembark")
	assert(car.position.distance_to(goal) < 6, "Driver must reach the turn destination")
	assert(maximum_speed > 5 and maximum_speed < 7)
	assert(car.health == car.MAX_HEALTH and absf(car.speed) < 0.1)
	assert(controller.route.is_empty() and controller.cooldown > 0)
	print("BOT_DRIVER_TURN_PASS turn=ok arrive=ok no_collision=ok exit=ok obstructed_route=ok reverse_rejected=ok")
	game.request_quit()
