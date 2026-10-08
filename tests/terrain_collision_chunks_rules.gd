extends SceneTree

const Chunks = preload("res://scripts/terrain_collision_chunks.gd")
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func run() -> void:
	var cell_size := 16.0
	var output := "../artifacts/android-terrain-collision-chunks-20260929"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--cell-size="):
			cell_size = argument.trim_prefix("--cell-size=").to_float()
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	var source: ConcavePolygonShape3D = load("res://assets/android_terrain_collision.res")
	var started := Time.get_ticks_usec()
	var chunks := Chunks.build(source, cell_size, "--single-tree" in OS.get_cmdline_user_args())
	var build_us := Time.get_ticks_usec() - started
	var original := source.get_faces()
	var triangle_counts := {}
	for i in range(0, original.size(), 3):
		var triangle := original.slice(i, i + 3)
		triangle_counts[triangle] = triangle_counts.get(triangle, 0) + 1
	var total_faces := 0
	for chunk in chunks:
		check(chunk.backface_collision == source.backface_collision, "Backface behavior preserved")
		var faces := chunk.get_faces()
		total_faces += faces.size()
		for i in range(0, faces.size(), 3):
			var triangle := faces.slice(i, i + 3)
			triangle_counts[triangle] = triangle_counts.get(triangle, 0) - 1
	check(total_faces == original.size(), "Exact face count preserved")
	for count in triangle_counts.values():
		check(count == 0, "Exact oriented triangle multiset preserved")
	var space := Node3D.new()
	root.add_child(space)
	var bodies: Array[StaticBody3D] = []
	for index in range(2):
		var body := StaticBody3D.new()
		body.collision_layer = 1 << index
		var shapes: Array[ConcavePolygonShape3D] = []
		if index == 0:
			shapes.append(source)
		else:
			shapes = chunks
		for shape in shapes:
			var collision := CollisionShape3D.new()
			collision.shape = shape
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
	var normal_mismatches := 0
	var normal_examples := []
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
			if before.normal.distance_to(after.normal) >= 0.0001:
				normal_mismatches += 1
				if normal_examples.size() < 24:
					normal_examples.append({"point": [point.x, point.y],
						"source": [before.normal.x, before.normal.y, before.normal.z],
						"chunked": [after.normal.x, after.normal.y, after.normal.z]})
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
		"cell_size": cell_size, "chunks": chunks.size(),
		"source_triangles": source.get_faces().size() / 3,
		"reduced_triangles": total_faces / 3,
		"build_us": build_us, "ray_samples": samples.size(),
		"normal_mismatches": normal_mismatches, "normal_examples": normal_examples,
		"capsule_sweeps": 1200, "capsule_mismatches": mismatches,
		"max_fraction_delta": max_fraction_delta, "mismatch_examples": mismatch_examples,
		"cast_us": timings, "passed": not failed,
		"scope": "Desktop physics experiment; no Android FPS claim or production collision replacement"
	}
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	print("TERRAIN_COLLISION_CHUNKS_", "FAIL" if failed else "PASS",
		" triangles=", report.source_triangles, " -> ", report.reduced_triangles,
		" rays=", samples.size(), " sweep_mismatches=", mismatches)
	space.queue_free()
	await process_frame
	quit(1 if failed else 0)
