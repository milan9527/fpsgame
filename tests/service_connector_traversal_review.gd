extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var visuals = load("res://scripts/world_visuals.gd")
	var route: Array[Vector2] = [Vector2(2, 49.2)]
	for index in range(11):
		route.append(visuals.service_access_point(1.0 - index * 0.055))
	var results := []
	var all_passed := true
	for reverse in [false, true]:
		var points := route.duplicate()
		if reverse:
			points.reverse()
		actor.position = Vector3(points[0].x, 0.4, points[0].y)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var reached := 1
		var highest: float = actor.position.y
		var lowest: float = actor.position.y
		for frame in range(600):
			var current := Vector2(actor.position.x, actor.position.z)
			if current.distance_to(points[reached]) < 0.22:
				reached += 1
				if reached == points.size():
					break
			actor.move_input = (points[reached] - current).normalized()
			await physics_frame
			actor.move_step(1.0 / 60.0)
			highest = maxf(highest, actor.position.y)
			lowest = minf(lowest, actor.position.y)
		var passed: bool = reached == points.size() and highest < 0.35 and lowest > -0.1
		all_passed = all_passed and passed
		results.append({"reverse": reverse, "waypoints_reached": reached,
			"waypoints_total": points.size(), "highest": highest, "lowest": lowest,
			"end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("connector-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": all_passed, "results": results}, "\t"))
	file.close()
	print("SERVICE_CONNECTOR_TRAVERSAL_", "PASS" if all_passed else "FAIL")
	quit(0 if all_passed else 1)
