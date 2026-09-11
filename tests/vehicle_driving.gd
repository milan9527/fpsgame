extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	for other in game.actors.values():
		other.is_bot = false
		other.position = Vector3(90, 0.1, 90 + other.actor_id)
	var actor = game.actors[1]
	actor.position = Vector3(-1.65, 0.04, 0.1)
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await physics_frame
	await physics_frame
	for _step in range(5):
		game.vehicle_fleet.step(1.0 / 60, true)
	game._process(0.016)
	assert("DRIVE BUGGY" in game.ui.prompt.text)
	var cmd: Dictionary = game.local_command(actor)
	cmd.loot = true
	game.apply_command(actor, cmd)
	assert(actor.is_seated() and actor.vehicle_seat == 0)
	Input.action_press("forward")
	for _step in range(90):
		game._physics_process(1.0 / 60)
	assert(car.speed > 10 and car.position.z < -5)
	game._process(0.016)
	assert(game.ui.vehicle_view and "DRIVER" in game.ui.weapon.text and "km/h" in game.ui.weapon.text and "BRAKE" in game.ui.loadout_label.text and "SLOW TO EXIT" in game.ui.prompt.text)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/vehicle-driving.png") == OK)
	var before: Vector3 = car.position
	Input.action_press("right")
	for _step in range(45):
		game._physics_process(1.0 / 60)
	assert(car.position.x > before.x + 1 and car.rotation.y < -0.1)
	Input.action_release("right")
	Input.action_release("forward")
	Input.action_press("jump")
	for _step in range(90):
		game._physics_process(1.0 / 60)
	assert(absf(car.speed) < 0.01 and not actor.jump_requested)
	Input.action_release("jump")
	Input.action_press("back")
	for _step in range(60):
		game._physics_process(1.0 / 60)
	assert(car.speed < -5)
	Input.action_release("back")
	game.ui.inventory.show()
	for _step in range(45):
		game._physics_process(1.0 / 60)
	assert(absf(car.speed) < 0.01)
	game.ui.inventory.hide()
	Input.action_press("forward")
	paused = true
	before = car.position
	game._physics_process(0.016)
	assert(car.position == before)
	paused = false
	Input.action_release("forward")
	cmd = game.local_command(actor)
	cmd.loot = true
	game.apply_command(actor, cmd)
	assert(not actor.is_seated() and actor.collision_mask == 7)
	game._process(0.016)
	assert(not game.ui.vehicle_view and "BUGGY" not in game.ui.weapon.text)
	# Passenger input cannot claim the driver's throttle.
	actor.position = car.to_global(car.seats.DOORS[1]) - Vector3.UP * 0.86
	assert(game.vehicle_fleet.interact(actor) and actor.vehicle_seat == 1)
	game._process(0.016)
	assert("PASSENGER" in game.ui.weapon.text and "THROTTLE" not in game.ui.loadout_label.text)
	Input.action_press("forward")
	for _step in range(30):
		game._physics_process(1.0 / 60)
	assert(car.driver_id == 0 and absf(car.speed) < 0.01)
	Input.action_release("forward")
	cmd = game.local_command(actor)
	cmd.loot = true
	game.apply_command(actor, cmd)
	assert(not actor.is_seated())
	actor.position = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.86
	assert(game.vehicle_fleet.interact(actor))
	Input.action_press("forward")
	for _step in range(30):
		game._physics_process(1.0 / 60)
	assert(car.speed > 2)
	cmd = game.local_command(actor)
	cmd.loot = true
	game.apply_command(actor, cmd)
	assert(actor.is_seated(), "Moving vehicles reject exit")
	game.phase = "finished"
	for _step in range(60):
		game._physics_process(1.0 / 60)
	assert(absf(car.speed) < 0.01)
	Input.action_release("forward")
	game.clear_actors()
	assert(game.vehicle_fleet.vehicles.is_empty() and game.actors.is_empty())
	game.running = false
	game.queue_free()
	await process_frame
	print("VEHICLE_DRIVING_PASS interaction=ok throttle=ok turn=ok handbrake=ok reverse=ok menu_brake=ok pause=ok passenger=ok exit=ok finish=ok cleanup=ok")
	quit()
