extends SceneTree
const Vehicle = preload("res://scripts/vehicle.gd")
var car
var sequence := 0

func _initialize() -> void:
	call_deferred("run")

func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body

func step(frames: int, pedal := 0.0, steer := 0.0, brake := false, send := true) -> void:
	for _i in range(frames):
		await physics_frame
		if send:
			assert(car.command(11, sequence, pedal, steer, brake))
			sequence += 1
		car.simulate(1.0 / 60.0)

func place(at := Vector3(0, 0.05, 0)) -> void:
	car.position = at
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	car.speed = 0
	car.steering = 0
	car.grounded = false
	car.reset_controls()

func run() -> void:
	solid(Vector3(0, -0.5, 0), Vector3(220, 1, 220))
	car = Vehicle.new()
	root.add_child(car)
	place()
	car.set_driver(11)
	assert(not car.command(99, 0, 1, 0, false))
	assert(not car.command(11, 0, NAN, 0, false))
	assert(not car.command(11, 0, 0, INF, false))
	assert(not car.command(11, 0, 2, 0, false))
	assert(not car.command(11, 10000, 1, 0, false))
	await step(180, 1)
	assert(car.grounded and absf(car.position.y) < 0.02)
	assert(car.speed > 20 and car.speed <= Vehicle.FORWARD_SPEED + 0.01)
	assert(car.position.z < -25)
	assert(car.wheel_rigs.size() == 4 and absf(car.wheel_rigs[0].roll.rotation.x) > 0.01)
	assert(not car.command(11, sequence - 1, 0, 0, false))
	await step(100, 0, 0, true)
	assert(absf(car.speed) < 0.01)
	var stopped: Vector3 = car.position
	await step(90, -1)
	assert(car.speed >= -Vehicle.REVERSE_SPEED - 0.01 and car.speed < -6.5)
	assert(car.position.z > stopped.z + 5)
	place()
	await step(150, 1, 1)
	assert(absf(car.rotation.y) > 0.5 and car.position.x > 2)
	assert(car.wheel_rigs[0].turn.rotation.y < -0.1 and car.wheel_rigs[2].turn.rotation.y == 0)
	place()
	await step(100, 1)
	assert(car.speed > 10)
	await step(140, 0, 0, false, false)
	assert(absf(car.speed) < 0.01, "Expired input must brake the vehicle")
	place()
	var wall := solid(Vector3(0, 2, -20), Vector3(10, 4, 1))
	await step(180, 1)
	assert(car.position.z >= -17.72 and car.position.z < -17.5, "Swept collision must stop at wall")
	assert(absf(car.speed) < 0.1, "Collision must remove speed, not keep stored throttle velocity")
	assert(not car.can_rotate(0.6), "Steering must not rotate the body through a nearby wall")
	wall.queue_free()
	await process_frame
	var parked = Vehicle.new()
	root.add_child(parked)
	parked.position = Vector3(0, 0, -16)
	place()
	await physics_frame
	# Newly added bodies need their transform and shape registration synchronized.
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0.9, -5), Vector3(0, 0.9, -25), 4, [car.get_rid()])
	var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.collider == parked, "Parked vehicle must exist in the physics space")
	await step(160, 1)
	assert(car.position.z > -12.5 and absf(car.speed) < 0.1, "Vehicles must collide with each other")
	car.set_driver(0)
	assert(not car.command(11, sequence, 1, 0, false))
	var before: Vector3 = car.position
	car.simulate(NAN)
	car.simulate(-1)
	car.simulate(1)
	assert(car.position == before)
	print("VEHICLE_MOTION_PASS grounded=ok speed_limit=ok brake=ok reverse=ok steering=ok stale_stop=ok wall_sweep=ok rotation_clearance=ok vehicle_collision=ok owner_sequence_bounds=ok")
	quit()
