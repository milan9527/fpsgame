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
		["road_to_workyard", Vector3(-12, 0.3, 49), Vector2(-1, 0), 210, "x", -32.0, -29.0],
		["tank_blocks_player", Vector3(-23, 0.3, 39), Vector2(0, 1), 90, "z", 41.2, 41.9]]:
		actor.position = route[1]
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(20):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		actor.move_input = route[2]
		for frame in range(route[3]):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var value: float = actor.position.x if route[4] == "x" else actor.position.z
		var passed: bool = value > route[5] and value < route[6]
		failed = failed or not passed
		results.append({"route": route[0], "start": str(route[1]), "end": str(actor.position), "passed": passed})
	var query := PhysicsRayQueryParameters3D.create(Vector3(-23, 1.72, 39), Vector3(-23, 1.72, 47), 1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	var shell_ok: bool = not hit.is_empty() and absf(hit.position.z - 41.88) < 0.05
	failed = failed or not shell_ok
	results.append({"tank_shell_hit": str(hit.get("position", Vector3.ZERO)), "passed": shell_ok})
	for side in [-1.0, 1.0]:
		var end_query := PhysicsRayQueryParameters3D.create(Vector3(-23 + side * 4, 1.72, 43), Vector3(-23, 1.72, 43), 1)
		end_query.exclude = [actor.get_rid()]
		var end_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(end_query)
		var end_ok: bool = not end_hit.is_empty() and absf(end_hit.position.x - (-23 + side * 2.5688)) < 0.06
		failed = failed or not end_ok
		results.append({"tank_end_side": side, "hit": str(end_hit.get("position", Vector3.ZERO)), "passed": end_ok})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("workyard-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("WORKYARD_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
