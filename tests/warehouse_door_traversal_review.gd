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
	for direction in [-1.0, 1.0]:
		actor.position = Vector3(35, 0.3, 34 - direction * 14)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var start: Vector3 = actor.position
		actor.move_input = Vector2(0, direction)
		for frame in range(420):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if (actor.position.z - 34) * direction > 13.5:
				break
		var passed: bool = (actor.position.z - 34) * direction > 13.5
		failed = failed or not passed
		results.append({"direction": direction, "start": str(start),
			"end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("warehouse-door-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed}, "\t"))
	file.close()
	print("WAREHOUSE_DOOR_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
