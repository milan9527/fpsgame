extends SceneTree

# Independent packaged-game diagnostic: exercise the real actor movement,
# including gravity and doorway floor transitions, rather than ray clearance.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	# Diagnostic control only: isolate the raised floor without changing assets.
	var floor_control := OS.get_environment("TRAVERSAL_DISABLE_FLOOR") == "1"
	var disabled_floors := 0
	if floor_control:
		for node in world.find_children("*", "CollisionShape3D", true, false):
			if node.shape is BoxShape3D and node.shape.size.is_equal_approx(Vector3(16, 0.2, 13)):
				if node.global_position.distance_to(Vector3(35, 0.1, 34)) < 0.01:
					node.set_deferred("disabled", true)
					disabled_floors += 1
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var failed := false
	for building_x in [35.0, -42.0]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(building_x, 0.3, 34 - direction * 10)
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
				if (actor.position.z - 34) * direction > 9:
					break
			var passed: bool = (actor.position.z - 34) * direction > 9
			failed = failed or not passed
			results.append({"building_x": building_x, "direction": direction, "start": str(start),
				"end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed,
		"floor_control": floor_control, "disabled_floors": disabled_floors}, "\t"))
	file.close()
	print("WAREHOUSE_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
