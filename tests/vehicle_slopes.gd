extends SceneTree
const Vehicle = preload("res://scripts/vehicle.gd")
var car
var sequence := 0

func _initialize() -> void:
	call_deferred("run")

func step(frames: int, pedal := 0.0, steer := 0.0, brake := false, send := true) -> void:
	for _i in range(frames):
		await physics_frame
		if send:
			assert(car.command(11, sequence, pedal, steer, brake))
			sequence += 1
		car.simulate(1.0 / 60)
		assert(car.position.is_finite() and car.velocity.is_finite())

func place(degrees: float, heading := 0.0) -> void:
	car.position = Vector3(0, 5 + tan(deg_to_rad(degrees)) * car.horizontal_extent(heading).y + 0.02, 0)
	car.rotation.y = heading
	car.velocity = Vector3.ZERO
	car.speed = 0
	car.steering = 0
	car.grounded = false
	car.reset_controls()

func run() -> void:
	# Catch the car below the finite steep ramp; this also verifies landing.
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(230, 1, 230)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	ground.position.y = -25.5
	root.add_child(ground)
	for degrees in [15.0, 30.0, 40.0]:
		var ramp := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(100, 1, 160)
		shape.shape = box
		ramp.add_child(shape)
		ramp.rotation.x = deg_to_rad(degrees)
		ramp.position.y = 5 - 0.5 / cos(ramp.rotation.x)
		root.add_child(ramp)
		car = Vehicle.new()
		root.add_child(car)
		place(degrees)
		car.set_driver(11)
		sequence = 0
		await step(15)
		var before: Vector3 = car.position
		await step(120, 1)
		print("SLOPE degrees=%s grounded=%s speed=%.3f displacement=%s" % [degrees, car.grounded, car.speed, car.position - before])
		if degrees <= 35:
			assert(car.grounded and car.speed > 15)
			assert(car.position.z < before.z - 12 and car.position.y > before.y + 3)
			await step(90, 0, 0, true)
			assert(car.grounded and absf(car.speed) < 0.01)
			before = car.position
			await step(90, 0, 0, true)
			assert(car.position.distance_to(before) < 0.02, "Parking brake must hold a driveable slope")
			await step(90, -1)
			assert(car.speed < -6.5 and car.grounded and car.position.y < before.y - 1)
			await step(90, 0, 0, false, false)
			assert(car.grounded and absf(car.speed) < 0.01, "Expired controls must stop downhill reverse")
			place(degrees)
			await step(15)
			before = car.position
			await step(90, 1, 1)
			assert(car.rotation.y < -1 and car.position.x > before.x + 4)
			place(degrees, PI / 2)
			await step(15)
			before = car.position
			await step(120, 1)
			print("SLOPE_SIDE degrees=%s displacement=%s velocity=%s" % [degrees, car.position - before, car.velocity])
			assert(car.grounded and car.position.x < before.x - 14)
			assert(absf(car.position.y - before.y) < 0.02 and absf(car.position.z - before.z) < 0.02,
				"Side-slope traction must prevent downhill drift")
			await step(90, 0, 0, true)
			before = car.position
			await step(90, 0, 0, true)
			assert(car.grounded and car.position.distance_to(before) < 0.02)
			print("SLOPE_DRIVE degrees=%s uphill=ok reverse_downhill=ok stale_brake=ok turn=ok sidehill=ok parking=ok" % degrees)
		else:
			assert(not car.grounded and car.position.z > before.z + 20 and car.position.y < before.y - 20,
				"Throttle must not climb terrain above the driveable slope limit")
			await step(180, 0, 0, true)
			assert(car.grounded and absf(car.position.y + 25) < 0.02)
			assert(absf(car.speed) < 0.01 and car.rotation.y == 0)
			print("SLOPE_STEEP slide=ok landing=ok stopped=ok")
		car.queue_free()
		ramp.queue_free()
		await process_frame
	var platform := StaticBody3D.new()
	var platform_shape := CollisionShape3D.new()
	var platform_box := BoxShape3D.new()
	platform_box.size = Vector3(10, 1, 10)
	platform_shape.shape = platform_box
	platform.add_child(platform_shape)
	platform.position.y = 2.5
	root.add_child(platform)
	car = Vehicle.new()
	root.add_child(car)
	car.position = Vector3(0, 3.02, 0)
	car.set_driver(11)
	sequence = 0
	await step(15)
	assert(car.grounded)
	var saw_falling := false
	for _i in range(180):
		await step(1, 1)
		if not car.grounded and car.position.y < 2 and car.velocity.y < -1:
			saw_falling = true
	assert(saw_falling, "Driving off a ledge must restore airborne gravity")
	await step(120, 0, 0, true)
	assert(car.grounded and absf(car.position.y + 25) < 0.02 and absf(car.speed) < 0.01)
	car.queue_free()
	platform.queue_free()
	ground.queue_free()
	await process_frame
	print("VEHICLE_SLOPES_PASS ledge_gravity=ok landing=ok")
	quit()
