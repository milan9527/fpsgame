extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var count := 0
	for roof in world.get_children():
		var body = roof.get_node_or_null("RoofCollision")
		if body == null: continue
		count += 1
		var space = world.get_world_3d().direct_space_state
		for x in [-6.0, 0.0, 6.0]:
			# Sample exposed slopes beyond the workshop ventilation monitor.
			var origin: Vector3 = roof.global_position + Vector3(x, 5, 5.5)
			var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0, 7, 0), 1)
			var hit: Dictionary = space.intersect_ray(query)
			assert(not hit.is_empty() and hit.collider == body, "Roof must stop incoming shots before the flat ceiling")
			var relative_height: float = hit.position.y - roof.global_position.y
			var gable: bool = roof.scene_file_path.contains("gable")
			var expected: float = 1.7 * (1.0 - absf(x) / 8.5) if gable else (x + 8.5) / 17.0 * 1.2
			assert(absf(relative_height - expected) < 0.025, "Collision must follow the rendered roof slope")
		var start: Vector3 = roof.global_position + Vector3(0, -2.5, -8)
		var through := PhysicsRayQueryParameters3D.create(start, start + Vector3(0, 0, 16), 1)
		assert(space.intersect_ray(through).is_empty(), "Roof must not obstruct the existing doorway")
	assert(count > 0 and count < 16, "Keep a mixture of flat and pitched roofs")
	var space = world.get_world_3d().direct_space_state
	for building_x in [35.0, -42.0]:
		for offset in [Vector3.ZERO, Vector3(0.8, 0, 2.1), Vector3(-0.8, 0, -2.1), Vector3(1.6, 0, 4.2), Vector3(-1.6, 0, -4.2)]:
			var origin: Vector3 = Vector3(building_x, 10, 34) + offset
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0, 8, 0), 1))
			assert(not hit.is_empty(), "Ventilation monitor must stop incoming shots")
			# The monitor now has two pitched sheets, not the old flat cap.
			# Check the top face, including the rotated sheet's half-thickness.
			var pitch := atan2(0.8, 1.95)
			var expected := 8.0 - absf(offset.x) * 0.8 / 1.95 + 0.0425 / cos(pitch)
			if is_zero_approx(offset.x):
				expected = 8.04 + 0.09 / 2.0
			assert(absf(hit.position.y - expected) < 0.025, "Monitor collision must follow its pitched sheet")
			if is_zero_approx(offset.x):
				assert(hit.normal.dot(Vector3.UP) > 0.999, "Visible ridge cap must stop shots on its top face")
			else:
				var expected_normal := Vector3(signf(offset.x) * sin(pitch), cos(pitch), 0)
				assert(hit.normal.dot(expected_normal) > 0.999, "Monitor collision normal must follow the visible slope")
	print("ROOF_COLLISION_PASS roofs=", count, " slopes=ok shots=blocked doorways=clear")
	quit()
