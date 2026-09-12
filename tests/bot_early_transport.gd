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
		actor.position = Vector3(95, 0.1, 95 + actor.actor_id)
	var bot = game.actors[-1]
	bot.position = Vector3(-6, 0.04, 0.1)
	bot.bot_destination = Vector3(-4, 0, 0)
	bot.bot_patrol_left = 100
	bot.navigator.finished = false
	game.zone = 110
	game.zone_center = Vector2.ZERO
	game.zone_state = {"next_center": Vector2(0, -70), "next_radius": 20.0, "moving": false, "remaining": 120.0}
	game.bot_input(bot, 1.0 / 60)
	assert(not bot.sprint and not bot.is_seated(), "Without transport, retain the normal walking-time decision")
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	var deadline := Time.get_ticks_msec() + 10000
	while not game.world.navigation_ready():
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	await physics_frame
	await physics_frame
	for _i in range(5):
		car.simulate(1.0 / 60)
	var controller = bot.navigator.driver
	controller.cooldown = 0
	car.fuel = 0
	game.bot_input(bot, 1.0 / 60)
	assert(not bot.sprint)
	car.fuel = 100
	controller.cooldown = 0
	bot.bot_memory_left = 2
	game.bot_input(bot, 1.0 / 60)
	assert(not bot.sprint and not bot.is_seated(), "Recent combat must not trigger optional vehicle rotation")
	bot.bot_memory_left = 0
	bot.health = 45
	controller.cooldown = 0
	game.bot_input(bot, 1.0 / 60)
	assert(not bot.sprint and not bot.is_seated(), "Low health must not trigger optional driving")
	bot.health = 100
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 4, 0.5)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = Vector3(0, 2, -20)
	await physics_frame
	await physics_frame
	controller.cooldown = 0
	game.bot_input(bot, 1.0 / 60)
	assert(not bot.sprint and not bot.is_seated(), "A nearby car without a clear route must not trigger early rotation")
	wall.queue_free()
	await physics_frame
	await physics_frame
	controller.cooldown = 0
	var entered := false
	var exited := false
	for _frame in range(900):
		await physics_frame
		game.bot_input(bot, 1.0 / 60)
		bot.simulate(1.0 / 60)
		car.simulate(1.0 / 60)
		entered = entered or bot.is_seated()
		if entered and not bot.is_seated():
			exited = true
			break
	assert(entered and exited, "Normal bot AI must approach, drive and exit before walking urgency")
	assert(car.position.z < -48 and car.health == car.MAX_HEALTH and absf(car.speed) < 0.1)
	assert(controller.cooldown > 0 and game.zone_state.remaining == 120)
	print("BOT_EARLY_TRANSPORT_PASS no_car=patrol no_fuel=patrol combat=priority low_health=patrol blocked_route=patrol approach=ok early_rotation=ok exit=ok")
	game.request_quit()
