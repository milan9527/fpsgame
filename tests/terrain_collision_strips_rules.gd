extends SceneTree

const Strips = preload("res://scripts/terrain_collision_strips.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func run() -> void:
	var max_quads := 0
	var output := "../artifacts/android-terrain-collision-strips-20260929"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--max-quads="):
			max_quads = argument.trim_prefix("--max-quads=").to_int()
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var source: ConcavePolygonShape3D = load("res://assets/android_terrain_collision.res")
	var started := Time.get_ticks_usec()
	var reduced := Strips.build(source, max_quads)
	var build_us := Time.get_ticks_usec() - started
	if max_quads == 1:
		check(reduced.get_faces() == source.get_faces(), "One-quad control preserves exact faces")
	else:
		check(reduced.get_faces().size() < source.get_faces().size(), "Real terrain must lose redundant faces")
	check(reduced.backface_collision == source.backface_collision, "Backface behavior preserved")
	var space := Node3D.new()
	root.add_child(space)
	var bodies: Array[StaticBody3D] = []
	for index in range(2):
		var body := StaticBody3D.new()
		body.collision_layer = 1 << index
		var collision := CollisionShape3D.new()
		collision.shape = source if index == 0 else reduced
		body.add_child(collision)
		space.add_child(body)
		bodies.append(body)
	await physics_frame
	await physics_frame
	var state := space.get_world_3d().direct_space_state
	var random := RandomNumberGenerator.new()
	random.seed = 20260929
	var ray := PhysicsRayQueryParameters3D.new()
	ray.hit_back_faces = true
	var samples: Array[Vector2] = []
	# Include the fine yard grid, coarse grid edges and random full-map points.
	for i in range(6000):
		samples.append(Vector2(random.randf_range(-119.99, 119.99), random.randf_range(-119.99, 119.99)))
	for z in range(-15, 52):
		for x in range(-15, 21):
			samples.append(Vector2(x, z))
	for point in samples:
		ray.from = Vector3(point.x, 20, point.y)
		ray.to = Vector3(point.x, -20, point.y)
		ray.collision_mask = 1
		var before := state.intersect_ray(ray)
		ray.collision_mask = 2
		var after := state.intersect_ray(ray)
		check(before.is_empty() == after.is_empty(), "Ray coverage at %s" % point)
		if not before.is_empty() and not after.is_empty():
			check(before.position.distance_to(after.position) < 0.0001, "Ray height at %s" % point)
			check(before.normal.distance_to(after.normal) < 0.0001, "Ray normal at %s" % point)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.motion = Vector3(0.15, -2, 0.09)
	var timings := [[], []]
	var mismatches := 0
	var mismatch_examples := []
	var max_fraction_delta := 0.0
	for i in range(1200):
		var point: Vector2 = samples[i]
		query.transform.origin = Vector3(point.x, 2.0, point.y)
		var results := []
		for variant in range(2):
			query.collision_mask = 1 << variant
			started = Time.get_ticks_usec()
			results.append(state.cast_motion(query))
			timings[variant].append(Time.get_ticks_usec() - started)
		if absf(results[0][0] - results[1][0]) > 0.001 or absf(results[0][1] - results[1][1]) > 0.001:
			mismatches += 1
			max_fraction_delta = maxf(max_fraction_delta, maxf(absf(results[0][0] - results[1][0]), absf(results[0][1] - results[1][1])))
			if mismatch_examples.size() < 20:
				mismatch_examples.append({"x": point.x, "z": point.y,
					"source": Array(results[0]), "reduced": Array(results[1])})
	check(mismatches == 0, "Capsule sweep mismatches: %d" % mismatches)
	var report := {
		"max_quads": max_quads,
		"source_triangles": source.get_faces().size() / 3,
		"reduced_triangles": reduced.get_faces().size() / 3,
		"build_us": build_us, "ray_samples": samples.size(),
		"capsule_sweeps": 1200, "capsule_mismatches": mismatches,
		"max_fraction_delta": max_fraction_delta, "mismatch_examples": mismatch_examples,
		"cast_us": timings, "passed": not failed,
		"scope": "Desktop physics experiment; no Android FPS claim or production collision replacement"
	}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("TERRAIN_COLLISION_STRIPS_", "FAIL" if failed else "PASS",
		" triangles=", report.source_triangles, " -> ", report.reduced_triangles,
		" rays=", samples.size(), " sweep_mismatches=", mismatches)
	space.queue_free()
	await process_frame
	quit(1 if failed else 0)
