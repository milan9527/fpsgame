extends SceneTree
const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run under Xvfb/OpenGL: headless MultiMesh transforms do not exercise root grouping.")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var checked := 0
	var results := []
	for fixture in [[80, 8.0], [80, 24.0], [256, 8.0], [256, 24.0], [256, 100.0]]:
		var count: int = fixture[0]
		var span: float = fixture[1]
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = QuadMesh.new()
		node.multimesh.instance_count = count
		for i in range(count):
			var p := Vector3(rng.randf_range(-span, span), rng.randf_range(-2, 2), rng.randf_range(-span, span))
			node.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		root.add_child(node)
		node.position = Vector3(-13, 7, 21)
		node.rotation.y = 0.61
		node.set_meta("mobile_animated_grass_fade", true)
		var setup_start := Time.get_ticks_usec()
		for repeat in range(2000):
			Mobile.DistanceEntry.new(node, node.global_position, 0, 30)
		var setup_us := Time.get_ticks_usec() - setup_start
		var grouped := Mobile.DistanceEntry.new(node, node.global_position, 0, 30)
		assert(grouped.grass_root_points.size() == count)
		assert(not grouped.grass_root_groups.is_empty())
		for index in range(count):
			var world_root: Vector3 = node.global_transform * node.multimesh.get_instance_transform(index).origin
			assert(grouped.grass_root_points[index].is_equal_approx(Vector2(world_root.x, world_root.z)))
		var flat := Mobile.DistanceEntry.new(node, node.global_position, 0, 30)
		flat.grass_root_groups.clear()
		flat.grass_group_bounds.clear()
		var cameras := PackedVector3Array()
		for i in range(6000):
			var camera := Vector3(rng.randf_range(-span-50, span+50), 200, rng.randf_range(-span-50, span+50)) + node.position
			if i % 4 == 0:
				var p: Vector2 = grouped.grass_root_points[i % count]
				camera = Vector3(p.x + [25.999, 26.0, 26.001][i % 3], -200, p.y)
			cameras.append(camera)
			var expected := false
			var nearest := INF
			for p in grouped.grass_root_points:
				var squared := Vector2(camera.x, camera.z).distance_squared_to(p)
				nearest = minf(nearest, squared)
				expected = expected or squared <= 676.0
			assert(grouped.grass_in_range(camera) == expected)
			assert(flat.grass_in_range(camera) == expected)
			# Height changes must preserve horizontal visibility for hits
			# and misses, including reuse of the previous nearest root.
			for height in [-201.0, 0.0, 201.0]:
				assert(grouped.grass_in_range(Vector3(camera.x, height, camera.z)) == expected)
			# A visibility-only search may cache a smaller empty disk than
			# an exact nearest-root search. Every point inside must remain
			# outside all roots, including groups that were never scanned.
			if not expected and grouped.grass_empty_center == Vector2(camera.x, camera.z):
				var radius := sqrt(grouped.grass_empty_radius_squared)
				for angle in [0.0, 0.7, 1.8, 3.1, 4.5, 5.7]:
					var probe := grouped.grass_empty_center + Vector2.from_angle(angle) * radius * 0.999
					if radius > 0.0:
						for p in grouped.grass_root_points:
							assert(probe.distance_squared_to(p) > 676.0, "Cached empty disk contains a visible root")
						assert(not grouped.grass_in_range_xz(probe))
			# Check the exact helper separately, including nearest-distance misses.
			if not grouped.grass_root_groups.is_empty():
				var index := grouped.grouped_nearest_root(Vector2(camera.x, camera.z), Vector2(camera.x, camera.z).distance_squared_to(grouped.grass_root_points[grouped.grass_near_root]))
				var found := Vector2(camera.x, camera.z).distance_squared_to(grouped.grass_root_points[index])
				assert(is_equal_approx(grouped.grass_search_nearest_squared, found))
				assert(found <= 676.0 if expected else is_equal_approx(found, nearest))
			checked += 1
		var flat_us := 0
		var grouped_us := 0
		for repeat in range(12):
			var entries := [flat, grouped] if repeat % 2 == 0 else [grouped, flat]
			for entry in entries:
				var start := Time.get_ticks_usec()
				for camera in cameras:
					entry.grass_in_range(camera)
				var elapsed := Time.get_ticks_usec() - start
				if entry == flat:
					flat_us += elapsed
				else:
					grouped_us += elapsed
		results.append({"count": count, "span": span, "groups": grouped.grass_root_groups.size(), "setup_2000_us": setup_us, "flat_us": flat_us, "grouped_us": grouped_us})
		node.free()
	print(JSON.stringify({"scope": "desktop CPU synthetic, not Android acceptance", "checked": checked, "timings": results}))
	print("GRASS_ROOT_GROUPS_PASS")
	quit()
