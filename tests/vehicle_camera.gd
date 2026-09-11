extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func obstacle(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	root.add_child(body)
	body.position = at
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	return body

func run() -> void:
	var floor_body := obstacle(Vector3(0, -0.1, 0), Vector3(40, 0.2, 40))
	var car = load("res://scripts/vehicle.gd").new()
	root.add_child(car)
	var actor = load("res://scripts/actor.gd").new()
	actor.actor_id = 11
	root.add_child(actor)
	actor.position = Vector3(-1.65, 0.04, 0.1)
	actor.set_local()
	await physics_frame
	await physics_frame
	for _step in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(actor, 0))
	actor.render_frame(0.1, false, true, true)
	var view = actor.vehicle_camera
	var camera: Camera3D = actor.camera
	var pivot: Vector3 = car.global_position + Vector3.UP * 1.4
	assert(view.active and camera.current and actor.body_mesh.visible)
	assert(is_equal_approx(camera.global_position.distance_to(pivot), 6.0))
	assert(camera.global_position.z > 5 and camera.global_position.y > 2)
	assert(not actor.gun.visible and not actor.third_person_gun.visible)
	assert(is_equal_approx(camera.fov, 78.0), "On-foot ADS must not zoom a seated camera")
	var yaw: float = actor.yaw
	view.orbit(Vector2(300, -10000), 0.003)
	assert(actor.yaw == yaw and is_equal_approx(view.orbit_pitch, 0.30))
	view.orbit(Vector2(0, 20000), 0.003)
	assert(is_equal_approx(view.orbit_pitch, -0.75))
	view.zoom(-100)
	assert(view.distance == 3)
	view.zoom(100)
	assert(view.distance == 8)
	view.orbit(Vector2(NAN, 0), 0.003)
	assert(is_finite(view.orbit_yaw))
	view.orbit_yaw = 0
	view.orbit_pitch = -0.18
	view.distance = 6
	var wall := obstacle(Vector3(0, 2, 3), Vector3(8, 4, 0.05))
	await physics_frame
	await physics_frame
	actor.render_frame(0.016, false, true, false)
	assert(camera.global_position.z < 2.72 and camera.global_position.z > 2.5, "Sphere radius must protect the near plane from a thin wall")
	var obstructed_distance: float = view.visible_distance
	wall.queue_free()
	await physics_frame
	await physics_frame
	actor.render_frame(0.016, false, true, false)
	assert(view.visible_distance > obstructed_distance and view.visible_distance < obstructed_distance + 0.09)
	for _step in range(60):
		actor.render_frame(1.0 / 60, false, true, false)
	assert(is_equal_approx(view.visible_distance, 6.0))
	car.rotation.y = PI / 2
	car.seats.refresh()
	actor.render_frame(0.1, false, true, false)
	assert(camera.global_position.x > 5 and absf(camera.global_position.z) < 0.02)
	# A large teleport must place the camera at the new car, without smoothing
	# through intervening world geometry or preserving walking prediction offsets.
	car.position = Vector3(10, 0, 0)
	car.seats.refresh()
	actor.camera_error = Vector3.ONE
	actor.render_frame(0.1, true, true, false)
	assert(camera.global_position.x > 15 and actor.camera_error == Vector3.ZERO)
	var other_car = load("res://scripts/vehicle.gd").new()
	root.add_child(other_car)
	other_car.position = Vector3(14, 0, 0)
	await physics_frame
	await physics_frame
	actor.render_frame(0.1, false, true, false)
	assert(camera.global_position.x < 12.8, "Other vehicles must obstruct the camera")
	other_car.queue_free()
	# The camera pivot inside an obstacle cannot sweep out through its far side.
	var blocker := obstacle(Vector3(10, 1.4, 0), Vector3(0.5, 0.5, 0.5))
	await physics_frame
	await physics_frame
	actor.render_frame(0.1, false, true, false)
	assert(view.visible_distance == 0 and not actor.body_mesh.visible)
	blocker.queue_free()
	await physics_frame
	await physics_frame
	assert(car.seats.exit(actor))
	actor.render_frame(0.1, false, true, false)
	assert(not view.active and not actor.body_mesh.visible and actor.gun.visible)
	assert(camera.position.is_zero_approx() and is_zero_approx(camera.rotation.y))
	assert(camera.fov > 78 and camera.fov <= 85)
	actor.queue_free()
	car.queue_free()
	floor_body.queue_free()
	await process_frame
	print("VEHICLE_CAMERA_PASS orbit=ok zoom=ok wall_sweep=ok obstruction_recovery=ok turn=ok teleport=ok vehicles=ok initial_overlap=ok exit=ok")
	quit()
