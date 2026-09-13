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
			var origin: Vector3 = roof.global_position + Vector3(x, 5, 0)
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
	print("ROOF_COLLISION_PASS roofs=", count, " slopes=ok shots=blocked doorways=clear")
	quit()
