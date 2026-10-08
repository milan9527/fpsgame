extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var visuals = load("res://scripts/world_visuals.gd")
	actor.position = Vector3(-10, 0.3, 26)
	for frame in range(20):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var results := []
	var passed := true
	# Off-grid probes compare the physical triangle surface to the shared
	# analytic height, allowing interpolation error on the half-metre grid.
	for point in [Vector2(-14.1, 26.2), Vector2(-13.2, 17.8),
			Vector2(-15.1, 24.8), Vector2(-9, 25), Vector2(0, 25)]:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, 3, point.y), Vector3(point.x, -0.5, point.y), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var expected: float = visuals.verge_height(point)
		var ok: bool = not hit.is_empty() and absf(hit.position.y - expected) < 0.04
		passed = passed and ok
		results.append({"point": str(point), "expected": expected,
			"hit": str(hit.get("position", Vector3.ZERO)), "passed": ok})
	actor.yaw = 0
	actor.move_input = Vector2(-1, 0)
	var highest: float = actor.position.y
	for frame in range(110):
		await physics_frame
		actor.move_step(1.0 / 60.0)
		highest = maxf(highest, actor.position.y)
	var crossed: bool = actor.position.x < -17.5 and highest > 0.3 and actor.position.y < 0.15
	passed = passed and crossed
	results.append({"route": "road_across_west_bank", "end": str(actor.position),
		"highest": highest, "passed": crossed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	var file := FileAccess.open(out.path_join("road-verge-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "results": results}, "\t"))
	file.close()
	print("ROAD_VERGE_TRAVERSAL_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
