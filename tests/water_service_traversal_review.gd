extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var failed := false
	for route in [
		{"at": Vector3(49.5, 0.3, 39), "direction": -1.0, "blocked": false},
		{"at": Vector3(49.5, 0.3, 28), "direction": 1.0, "blocked": false},
		{"at": Vector3(46, 0.3, 39), "direction": -1.0, "blocked": true}]:
		actor.position = route.at
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var start: Vector3 = actor.position
		actor.move_input = Vector2(0, route.direction)
		for frame in range(240):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if not route.blocked and (actor.position.z - start.z) * route.direction >= 10.9:
				break
		var distance: float = (actor.position.z - start.z) * route.direction
		var passed: bool = distance >= 10.9 if not route.blocked else (distance > 3 and actor.position.z > 32.8 and actor.position.z < 34)
		failed = failed or not passed
		results.append({"start": str(start), "end": str(actor.position), "blocked_expected": route.blocked, "passed": passed})
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(46, 2, 36), Vector3(46, 2, 30), 1))
	var cylinder_pass: bool = not hit.is_empty() and absf(hit.position.z - 32.65) < 0.06
	failed = failed or not cylinder_pass
	results.append({"tank_hit": str(hit.get("position", Vector3.ZERO)), "passed": cylinder_pass})
	var cap_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(46, 6, 31), Vector3(46, 4, 31), 1))
	var cap_pass: bool = not cap_hit.is_empty() and absf(cap_hit.position.y - 4.484) < 0.03
	failed = failed or not cap_pass
	results.append({"cap_hit": str(cap_hit.get("position", Vector3.ZERO)), "passed": cap_pass})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("water-service-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed}, "\t"))
	file.close()
	print("WATER_SERVICE_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
