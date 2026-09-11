extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var car = load("res://scripts/vehicle.gd").new()
	root.add_child(car)
	assert(car.visual != null)
	var meshes: Array = car.visual.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	var wheels := {}
	for mesh in meshes:
		var box: AABB = mesh.mesh.get_aabb()
		for i in range(8):
			var point: Vector3 = mesh.global_transform * box.get_endpoint(i)
			if first:
				bounds = AABB(point, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
		if str(mesh.name) in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
			wheels[str(mesh.name)] = mesh.global_position
	assert(wheels.size() == 4)
	assert(wheels.Wheel_FL.z < wheels.Wheel_RL.z, "Exported forward axis must be Godot -Z")
	assert(bounds.position.y >= -0.02 and bounds.end.y <= 1.82)
	assert(bounds.size.x < 1.95 and bounds.size.z < 3.62)
	for angle in [-deg_to_rad(28), deg_to_rad(28)]:
		for rig in car.wheel_rigs:
			rig.turn.rotation.y = angle if rig.front else 0.0
		for mesh in meshes:
			for i in range(8):
				var point: Vector3 = mesh.global_transform * mesh.mesh.get_aabb().get_endpoint(i)
				assert(absf(point.x) <= car.BODY_SIZE.x / 2 and absf(point.z) <= car.BODY_SIZE.z / 2, "Full-lock tires must remain inside the collision envelope")
	for rig in car.wheel_rigs:
		rig.turn.rotation.y = 0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(5, 3.4, -6)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.current = true
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if output.is_empty():
		output = "res://../artifacts"
	assert(root.get_texture().get_image().save_png(output.path_join("buggy-render.png")) == OK)
	print("VEHICLE_RENDER_PASS wheels=4 axis=negative_z ground_contact=ok collision_envelope=ok bounds=%s" % bounds)
	quit()
