extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var android_terrain := OS.get_environment("CAPTURE_ANDROID_TERRAIN") == "1"
	if android_terrain:
		var replacements := 0
		for terrain in world.find_children("ExcavatedTerrain", "MeshInstance3D", true, false):
			var shapes: Array[Node] = terrain.find_children("*", "CollisionShape3D", true, false)
			assert(shapes.size() == 1)
			var cached_shape: Shape3D = load("res://assets/android_terrain_collision.res")
			assert(cached_shape != null)
			shapes[0].shape = cached_shape
			replacements += 1
		assert(replacements == 1)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var passed := true
	# Cross both depressed wheel tracks and their lips at two points on the turn.
	for z in [40.0, 44.0]:
		for direction in [-1.0, 1.0]:
			var start := Vector3(15.5 - direction * 3.5, 1.2, z)
			actor.position = start
			actor.velocity = Vector3.ZERO
			actor.yaw = 0.0
			actor.move_input = Vector2.ZERO
			for frame in range(60):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			var lowest: float = actor.position.y
			var highest: float = actor.position.y
			var peak_position: Vector3 = actor.position
			var peak_colliders := []
			var distance := 0.0
			var blockers := {}
			actor.move_input = Vector2(direction, 0.0)
			for frame in range(240):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				lowest = minf(lowest, actor.position.y)
				if actor.position.y > highest:
					highest = actor.position.y
					peak_position = actor.position
					peak_colliders.clear()
					for index in range(actor.get_slide_collision_count()):
						var collider = actor.get_slide_collision(index).get_collider()
						if is_instance_valid(collider):
							peak_colliders.append(str(collider.get_path()))
				for index in range(actor.get_slide_collision_count()):
					var collision = actor.get_slide_collision(index)
					if absf(collision.get_normal().y) < 0.7:
						var collider = collision.get_collider()
						if is_instance_valid(collider):
							blockers[str(collider.get_path())] = str(collider.global_position)
				distance = (actor.position.x - start.x) * direction
				if distance > 7.0:
					break
			var ok: bool = distance > 7.0 and highest < 0.65 and lowest > -0.5
			passed = passed and ok
			results.append({"start": str(start), "end": str(actor.position),
				"direction": direction, "distance": distance, "highest": highest, "lowest": lowest,
				"peak_position": str(peak_position), "peak_colliders": peak_colliders,
				"blocking_colliders": blockers, "passed": ok})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("service-yard-rut-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "results": results,
		"cached_android_terrain_collision": android_terrain,
		"scope": "desktop full world traversal; not Android frame rate"}, "\t"))
	file.close()
	print("SERVICE_YARD_RUT_TRAVERSAL_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
