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
	for route in [Vector3(-26, 0.1, 63), Vector3(12, 0.1, -26), Vector3(-25, 0.1, -6)]:
		actor.position = route
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2(0, -1)
		var peak := 0.0
		for frame in range(330):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			peak = maxf(peak, actor.position.y)
		var passed: bool = peak > 0.65 and actor.position.z < route.z - 24 and actor.position.y < 0.15
		failed = failed or not passed
		results.append({"start": str(route), "end": str(actor.position), "peak": peak, "passed": passed})
	for x in [-57.0, -53.9]:
		actor.position = Vector3(x, 0.1, -12)
		actor.velocity = Vector3.ZERO
		actor.move_input = Vector2(0, -1)
		for frame in range(160):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var passed: bool = actor.position.z > -15.5 if x == -57.0 else actor.position.z < -23.0
		failed = failed or not passed
		results.append({"silo_route_x": x, "end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("verge-silo.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("VERGE_SILO_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
