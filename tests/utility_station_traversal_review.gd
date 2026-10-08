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
	# Traverse both doors, slab ramps and the new canopy with real movement.
	for direction in [-1.0, 1.0]:
		actor.position = Vector3(-42, 0.3, -35 - direction * 14)
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
			if (actor.position.z + 35) * direction > 13.5:
				break
		var passed: bool = (actor.position.z + 35) * direction > 13.5
		failed = failed or not passed
		results.append({"direction": direction, "start": str(start),
			"end": str(actor.position), "passed": passed})
	# Walk into the new front post, independently of the clear doorway route.
	actor.position = Vector3(-34.5, 0.3, -21)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	actor.move_input = Vector2(0, -1)
	for frame in range(100):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var post_ok: bool = actor.position.z > -24.2 and actor.position.z < -23.6
	failed = failed or not post_ok
	results.append({"route": "front_post", "end": str(actor.position), "passed": post_ok})
	var query := PhysicsRayQueryParameters3D.create(Vector3(-42, 2, -26.4), Vector3(-42, 5, -26.4), 1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	var roof_ok: bool = not hit.is_empty() and hit.position.y > 3.4 and hit.position.y < 3.7
	failed = failed or not roof_ok
	results.append({"roof_hit": str(hit.get("position", Vector3.ZERO)), "passed": roof_ok})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("utility-station-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed}, "\t"))
	file.close()
	print("UTILITY_STATION_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
