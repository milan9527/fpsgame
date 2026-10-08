extends SceneTree

# Independent packaged-game diagnostic: exercise the real actor movement,
# including gravity and doorway floor transitions, rather than ray clearance.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var failed := false
	for route in [{"name": "canopy", "x": 23.5, "z": 31.0, "distance": 13.0},
		{"name": "front-door", "x": 35.0, "z": 39.0, "distance": 5.0},
		{"name": "repair-service-entry", "x": 15.5, "z": 37.0, "distance": 8.0}]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(route.x, 0.3, route.z - direction * route.distance)
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			var start: Vector3 = actor.position
			actor.move_input = Vector2(0, direction)
			for frame in range(360):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if (actor.position.z - route.z) * direction > route.distance - 0.5:
					break
			var passed: bool = (actor.position.z - route.z) * direction > route.distance - 0.5
			failed = failed or not passed
			results.append({"route": route.name, "direction": direction, "start": str(start),
				"end": str(actor.position), "passed": passed})
	for side in [-1.0, 1.0]:
		var x: float = 35.0 + side * 2.38
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 0.77, 44), Vector3(x, 0.77, 40.9))
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = not hit.is_empty() and hit.position.z > 41.0
		failed = failed or not passed
		results.append({"guard_side": side, "passed": passed, "hit": str(hit.get("position", "none"))})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("depot-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed}, "\t"))
	file.close()
	print("DEPOT_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
