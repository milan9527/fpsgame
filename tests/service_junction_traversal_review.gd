extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await physics_frame
	var results := []
	var failed := false
	# Probe both sides of the road/apron join, then actually cross it.
	for z in [46.5, 49.2, 51.5]:
		for x in [7.8, 8.0, 8.2, 9.0]:
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(Vector3(x, 2, z), Vector3(x, -1, z)))
			var passed: bool = not hit.is_empty() and absf(hit.position.y) < 0.12 and hit.normal.y > 0.8
			failed = failed or not passed
			results.append({"kind": "support", "x": x, "z": z,
				"position": str(hit.get("position")), "normal": str(hit.get("normal")), "passed": passed})
		for direction in [-1.0, 1.0]:
			var start := Vector3(8.0 - direction * 2.0, 0.35, z)
			actor.position = start
			actor.velocity = Vector3.ZERO
			actor.yaw = 0.0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			actor.move_input = Vector2(direction, 0.0)
			var distance := 0.0
			var max_height: float = actor.position.y
			for frame in range(180):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				distance = (actor.position.x - start.x) * direction
				max_height = maxf(max_height, actor.position.y)
				if distance >= 4.0:
					break
			var passed: bool = distance >= 4.0 and max_height < 0.5 and actor.position.y > -0.1
			failed = failed or not passed
			results.append({"kind": "crossing", "z": z, "direction": direction,
				"distance": distance, "max_height": max_height, "end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("junction-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "results": results}, "\t"))
	file.close()
	print("JUNCTION_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
