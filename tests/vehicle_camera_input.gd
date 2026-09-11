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
	var actor = game.actors[1]
	var car = load("res://scripts/vehicle.gd").new()
	game.add_child(car)
	actor.position = Vector3(-1.65, 0.04, 0.1)
	await physics_frame
	await physics_frame
	for _step in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(actor, 0))
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 50)
	var actor_yaw: float = actor.yaw
	var actor_pitch: float = actor.pitch
	game._unhandled_input(motion)
	var view = actor.vehicle_camera
	assert(view.active and view.orbit_yaw < 0 and view.orbit_pitch < -0.18)
	assert(actor.yaw == actor_yaw and actor.pitch == actor_pitch)
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_UP
	scroll.pressed = true
	game._unhandled_input(scroll)
	assert(view.distance == 5.5)
	var orbit_before: float = view.orbit_yaw
	for panel in [game.ui.pause_panel, game.ui.inventory, game.ui.tactical_map, game.ui.controls]:
		panel.show()
		game._unhandled_input(motion)
		game._unhandled_input(scroll)
		assert(view.orbit_yaw == orbit_before and view.distance == 5.5)
		panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._unhandled_input(motion)
	assert(view.orbit_yaw == orbit_before)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.alive = false
	game._unhandled_input(motion)
	assert(view.orbit_yaw == orbit_before, "Dead players use spectator input")
	actor.alive = true
	view.orbit_yaw = 0.35
	actor.render_frame(0.1, false, true, false)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/vehicle-camera-view.png") == OK)
	assert(car.seats.exit(actor))
	actor.render_frame(0.1, false, true, false)
	game._unhandled_input(motion)
	assert(actor.yaw != actor_yaw, "Walking mouse look must resume after exit")
	game.running = false
	game.queue_free()
	await process_frame
	print("VEHICLE_CAMERA_INPUT_PASS mouse_orbit=ok zoom=ok menus=ok uncaptured=ok spectator=ok walking_restore=ok")
	quit()
