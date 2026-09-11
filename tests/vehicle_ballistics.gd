extends SceneTree
const Ballistics = preload("res://scripts/vehicle_ballistics.gd")

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var root_3d := Node3D.new()
	root.add_child(root_3d)
	var car = load("res://scripts/vehicle.gd").new()
	root_3d.add_child(car)
	var geometry = car.ballistics
	await sync_physics()
	assert(geometry.bodies.size() > 20)
	var space := root_3d.get_world_3d().direct_space_state
	for body in geometry.bodies:
		assert(body.collision_layer == 16 and body.collision_mask == 0)
		assert(body.get_parent() is MeshInstance3D)
	# Actual Blender hood, sill and tire geometry, rather than a guessed box.
	var hood := Ballistics.trace(space, Vector3(0, 0.93, -4), Vector3.BACK)
	assert(hood.collider == car and hood.part == "Hood")
	var opening := Ballistics.trace(space, Vector3(-4, 1.3, 0), Vector3.RIGHT)
	assert(opening.is_empty(), "An empty open cockpit cannot stop a bullet")
	var sill := Ballistics.trace(space, Vector3(-4, 0.72, 0), Vector3.RIGHT)
	assert(sill.collider == car and sill.part.begins_with("Side sill"), str(sill))
	var tire := Ballistics.trace(space, Vector3(-4, 0.70, -1.2), Vector3.RIGHT)
	assert(tire.collider == car and tire.part == "Wheel_FL", str(tire))
	var roof := Ballistics.trace(space, Vector3(0, 3, -0.34), Vector3.DOWN)
	assert(roof.collider == car and roof.part.begins_with("Roof cross rail"), str(roof))
	# Isolated geometry does not alter the existing broad movement hull.
	var hull := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-4, 1.3, 0), Vector3(4, 1.3, 0), 4))
	assert(hull.collider == car)
	car.position = Vector3(10, 0, 5)
	car.rotation.y = PI / 2
	await sync_physics()
	var moved := Ballistics.trace(space, car.to_global(Vector3(0, 0.93, -4)), car.global_basis.z)
	assert(moved.collider == car and moved.part == "Hood")
	assert(Ballistics.trace(space, Vector3(0, 0.93, -4), Vector3.BACK).is_empty())
	var wheel = car.wheel_rigs[0].turn
	wheel.rotation.y = 0.4
	await sync_physics()
	for body in geometry.bodies:
		assert(body.global_transform.is_equal_approx(body.get_parent().global_transform))
	assert(Ballistics.trace(space, Vector3.ZERO, Vector3.ZERO).is_empty())
	assert(Ballistics.trace(space, Vector3(NAN, 0, 0), Vector3.RIGHT).is_empty())
	geometry.clear()
	await sync_physics()
	assert(geometry.bodies.is_empty())
	assert(Ballistics.trace(space, car.to_global(Vector3(0, 0.93, -4)), car.global_basis.z).is_empty())
	geometry.build(car)
	await sync_physics()
	assert(not geometry.bodies.is_empty())
	car.queue_free()
	await sync_physics()
	geometry.clear()
	assert(geometry.bodies.is_empty(), "Owner deletion must also release mesh collision bodies")
	root_3d.queue_free()
	await process_frame
	print("VEHICLE_BALLISTICS_GEOMETRY_PASS mesh=ok hood=ok opening=ok sill=ok tire=ok frame=ok movement_separate=ok transform=ok wheel_rig=ok cleanup=ok owner_deletion=ok")
	quit()
