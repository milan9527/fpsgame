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
	# Walk the road and its western verge through all new tree groups.
	for x in [0.0, -12.0]:
		actor.position = Vector3(x, 0.3, 50)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2(0, -1)
		for frame in range(1400):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if actor.position.z < -60:
				break
		var passed: bool = actor.position.z < -60 and absf(actor.position.x - x) < 0.2
		failed = failed or not passed
		results.append({"route_x": x, "end": str(actor.position), "passed": passed})
	actor.position = Vector3(-17, 0.3, 21)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	for frame in range(100):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var blocked: bool = actor.position.z > 18.3 and actor.position.z < 19.0
	failed = failed or not blocked
	results.append({"tree_stops_actor": blocked, "end": str(actor.position)})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("roadside-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("ROADSIDE_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
