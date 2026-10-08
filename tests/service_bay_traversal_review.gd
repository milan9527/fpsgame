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
		["south_entry", Vector3(-30, 0.3, 45), Vector2(0, -1), 150, 30.0, 33.0],
		["south_exit", Vector3(-30, 0.3, 32), Vector2(0, 1), 150, 44.0, 47.0],
		["column", Vector3(-26.3, 0.3, 43), Vector2(0, -1), 90, 40.2, 40.8],
		["rear_wall", Vector3(-30, 0.3, 30), Vector2(0, -1), 90, 26.3, 27.2]]:
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
		var passed: bool = actor.position.z > route[4] and actor.position.z < route[5]
		failed = failed or not passed
		results.append({"route": route[0], "start": str(route[1]), "end": str(actor.position), "passed": passed})
	var query := PhysicsRayQueryParameters3D.create(Vector3(-30, 2, 34), Vector3(-30, 6, 34), 1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	var roof_ok: bool = not hit.is_empty() and hit.position.y > 3.5 and hit.position.y < 3.9
	failed = failed or not roof_ok
	results.append({"roof_hit": str(hit.get("position", Vector3.ZERO)), "passed": roof_ok})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("service-bay-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("SERVICE_BAY_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
