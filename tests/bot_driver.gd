extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func wall(parent, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	body.position = at
	return body

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
	bot.position = Vector3(-6, 0.04, 0.1)
	game.zone = 5
	game.zone_center = Vector2(0, -35)
	game.zone_state = {}
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	var navigation_deadline := Time.get_ticks_msec() + 10000
	while not game.world.navigation_ready():
		assert(Time.get_ticks_msec() < navigation_deadline)
		await process_frame
	await physics_frame
	await physics_frame
	for _i in range(5):
		car.simulate(1.0 / 60)
	var controller = bot.navigator.driver
	assert(controller.flat_route(car, Vector3(0, 0, -35), bot))
	# Low fuel and combat priority must retain infantry behavior.
	car.fuel = 0
	controller.approach(game, bot, Vector3(0, 0, -35), 1, true)
	assert(not bot.is_seated())
	car.fuel = 100
	controller.approach(game, bot, Vector3(0, 0, -35), 1, false)
	assert(not bot.is_seated())
	var entered := false
	var moved := false
	var exited := false
	for _frame in range(600):
		await physics_frame
		game.bot_input(bot, 1.0 / 60)
		bot.simulate(1.0 / 60)
		car.simulate(1.0 / 60)
		entered = entered or bot.is_seated()
		moved = moved or car.speed > 10
		if entered and not bot.is_seated():
			exited = true
			break
	assert(entered and moved and exited, "Normal bot_input must board, drive and disembark for the safe zone")
	assert(car.position.z < -28 and car.position.z > -36 and absf(car.speed) < 0.1)
	assert(bot.collision_mask == 7 and car.driver_id == 0 and car.fuel < 100)
	assert(controller.cooldown > 0 and not controller.destination.is_finite())
	car.position = Vector3.ZERO
	bot.position = Vector3(-1.65, 0.04, 0.1)
	var blocker := wall(game, Vector3(0, 2, -15))
	await physics_frame
	await physics_frame
	controller.approach(game, bot, Vector3(0, 0, -35), 10, true)
	assert(not bot.is_seated(), "Blocked corridors must not be selected")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	controller.cooldown = 0
	game.bot_input(bot, 1.0 / 60)
	assert(bot.is_seated())
	for _i in range(60):
		await physics_frame
		game.bot_input(bot, 1.0 / 60)
		car.simulate(1.0 / 60)
	assert(car.speed > 7)
	blocker = wall(game, car.position + Vector3(0, 2, -9))
	await physics_frame
	await physics_frame
	for _i in range(180):
		await physics_frame
		game.bot_input(bot, 1.0 / 60)
		car.simulate(1.0 / 60)
		if not bot.is_seated():
			break
	assert(not bot.is_seated() and car.speed < 0.1)
	assert(car.position.z > blocker.position.z + 2.1 and car.health == car.MAX_HEALTH,
		"Dynamic obstacle must trigger braking before hull collision")
	print("BOT_DRIVER_PASS normal_ai=ok low_fuel=ok combat_priority=ok board=ok drive=ok brake=ok exit=ok cooldown=ok blocked_route=ok dynamic_obstacle=ok")
	game.request_quit()
