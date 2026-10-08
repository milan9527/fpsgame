extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var visuals = load("res://scripts/world_visuals.gd")
	var results := []
	var failed := false
	await physics_frame
	for t in [0.60, 0.85]:
		var center: Vector2 = visuals.service_access_point(t)
		var tangent: Vector2 = (visuals.service_access_point(t + 0.002) - visuals.service_access_point(t - 0.002)).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		for side in [-1.0, 1.0]:
			var width := lerpf(2.45, 3.40, smoothstep(0.34, 0.86, t))
			if side > 0.0:
				width -= 0.42 * sin(t * PI)
			var irregularity: float = sin(t * 39.0 + side) * 0.13 + sin(t * 91.0) * 0.045
			var crest: Vector2 = center + normal * side * (width + irregularity)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(Vector3(crest.x, 2, crest.y), Vector3(crest.x, -1, crest.y)))
			# The road junction deliberately flattens the shoulder west of x=10.
			# Check a raised crest inland and a low, supported join at the road.
			var junction: bool = crest.x < 10.0 and side > 0.0
			var min_height: float = 0.04 if junction else 0.11
			var max_support_height: float = 0.09 if junction else 0.22
			var support_ok: bool = not hit.is_empty() and hit.position.y > min_height and hit.position.y < max_support_height and hit.normal.y > 0.8
			failed = failed or not support_ok
			results.append({"t": t, "side": side, "kind": "crest_support",
				"position": str(hit.get("position")), "normal": str(hit.get("normal")),
				"junction": junction, "height_bounds": [min_height, max_support_height], "passed": support_ok})
			for direction in [-1.0, 1.0]:
				var start: Vector2 = crest - normal * direction * 1.8
				actor.position = Vector3(start.x, 0.4, start.y)
				actor.velocity = Vector3.ZERO
				actor.yaw = 0
				actor.move_input = Vector2.ZERO
				for frame in range(30):
					await physics_frame
					actor.move_step(1.0 / 60.0)
				actor.move_input = normal * direction
				var traveled := 0.0
				var max_height: float = actor.position.y
				for frame in range(180):
					await physics_frame
					actor.move_step(1.0 / 60.0)
					max_height = maxf(max_height, actor.position.y)
					traveled = (Vector2(actor.position.x, actor.position.z) - start).dot(normal * direction)
					if traveled >= 3.5:
						break
				var passed: bool = traveled >= 3.5 and max_height < 0.5
				failed = failed or not passed
				results.append({"t": t, "side": side, "direction": direction, "kind": "actor_crossing",
					"distance": traveled, "max_height": max_height, "end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("shoulder-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("SHOULDER_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
