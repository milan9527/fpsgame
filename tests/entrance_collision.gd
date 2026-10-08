extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var count := 0
	var space = world.get_world_3d().direct_space_state
	for hood in world.get_children():
		if not hood.has_meta("entrance_hood"):
			continue
		count += 1
		# Sample the hood's immediate underside. The west workshop now has
		# a lower canopy, tested separately by west_workshop_traversal_review.
		for x in [-2.4, 0.0, 2.4]:
			var origin: Vector3 = hood.position + Vector3(x, -0.1, 0)
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				origin, origin + Vector3(0, 1, 0), 1))
			assert(not hit.is_empty() and hit.collider == hood, "Rain hood must block shots")
			assert(absf(hit.position.y - (hood.position.y - 0.04)) < 0.005)
	assert(count >= 2)
	print("ENTRANCE_COLLISION_PASS hoods=", count, " underside_shots=", count * 3)
	quit()
