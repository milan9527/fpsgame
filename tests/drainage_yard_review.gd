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
	for center in [Vector3(-19, 0, 34), Vector3(17, 0, 17)]:
		var space = world.get_world_3d().direct_space_state
		var bore: Vector3 = center + Vector3(-0.9, 0.9, 0)
		var hollow_query := PhysicsRayQueryParameters3D.create(
			bore + Vector3(0, 0, 2.1), bore - Vector3(0, 0, 2.1), 1)
		hollow_query.exclude = [actor.get_rid()]
		var hollow: bool = space.intersect_ray(hollow_query).is_empty()
		var wall_query := PhysicsRayQueryParameters3D.create(
			bore + Vector3(-1.2, 0, 0), bore, 1)
		wall_query.exclude = [actor.get_rid()]
		var hit: Dictionary = space.intersect_ray(wall_query)
		var wall: bool = not hit.is_empty() and absf(hit.position.x - (bore.x - 0.88)) < 0.02
		# Start inside the existing z=22 fence to isolate the pipe collision.
		actor.position = center + Vector3(-0.9, 0.3, 3)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2(0, -1)
		for frame in range(150):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var stopped_at: Vector3 = actor.position
		var stopped: bool = stopped_at.z > center.z + 1.75 and stopped_at.z < center.z + 2.6
		# Test the local aisle inside the existing fence at z=22.
		actor.position = center + Vector3(-3.5, 0.3, 3)
		actor.velocity = Vector3.ZERO
		for frame in range(260):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if actor.position.z < center.z - 5:
				break
		var bypass: bool = actor.position.z < center.z - 5
		failed = failed or not (hollow and wall and stopped and bypass)
		results.append({"center": str(center), "bore_open": hollow,
			"wall_matches_mesh": wall, "wall_hit": str(hit.get("position")),
			"actor_stopped": stopped, "stopped_at": str(stopped_at),
			"bypass": bypass, "bypass_end": str(actor.position)})
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("drainage-yard-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "yards": results}, "\t"))
	file.close()
	print("DRAINAGE_YARD_REVIEW_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
