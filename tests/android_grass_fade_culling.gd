extends SceneTree
# Requires a real rendering backend: Dummy does not retain MultiMesh transforms.

const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Disabled capacity near the camera must not keep a batch whose enabled
	# prefix is distant. Include empty capacity and the -1 (all) convention.
	var partial := MultiMeshInstance3D.new()
	partial.multimesh = MultiMesh.new()
	partial.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	partial.multimesh.mesh = QuadMesh.new()
	partial.multimesh.instance_count = 128
	for i in range(128):
		var position := Vector3(100, 0, 0) if i < 64 else Vector3.ZERO
		partial.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, position))
	partial.set_meta("mobile_animated_grass_fade", true)
	root.add_child(partial)
	for count in [0, 1, 64, 65, -1]:
		partial.multimesh.visible_instance_count = count
		var prefix := Mobile.DistanceEntry.new(partial, Vector3.ZERO, 0, 30)
		assert(prefix.grass_root_points.size() == (128 if count == -1 else count))
		assert(prefix.grass_in_range(Vector3.ZERO) == (count == -1 or count > 64))
		assert(prefix.grass_in_range(Vector3(100, 0, 0)) == (count != 0))
	partial.multimesh.instance_count = 0
	var empty := Mobile.DistanceEntry.new(partial, Vector3.ZERO, 0, 30)
	assert(not empty.grass_in_range(Vector3.ZERO))
	partial.free()
	print("GRASS_ACTIVE_PREFIX_CULL_PASS")
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = QuadMesh.new()
	node.multimesh.instance_count = 4
	var roots := [Vector3(-6, 0, -6), Vector3(6, 1, -6),
		Vector3(-6, 2, 6), Vector3(6, 3, 6)]
	for i in range(roots.size()):
		node.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, roots[i]))
	node.set_meta("mobile_animated_grass_fade", true)
	root.add_child(node)
	node.position = Vector3(10, 4, -20)
	node.rotation.y = 0.7
	var entry := Mobile.DistanceEntry.new(node, node.global_position, 0, 30)
	var checked := 0
	var skipped := 0
	var avoided := 0
	for x in range(-40, 61, 2):
		for z in range(-70, 31, 2):
			var camera := Vector3(x, 200, z)
			var any_visible := false
			for local_root in roots:
				var world_root: Vector3 = node.global_transform * local_root
				any_visible = any_visible or Vector2(camera.x, camera.z).distance_to(
					Vector2(world_root.x, world_root.z)) < 24.0
			var keep := entry.grass_in_range(camera)
			assert(keep == roots_in_range(node, roots, camera),
				"camera=%s keep=%s roots=%s" % [camera, keep, entry.grass_root_points])
			assert(not keep or original_in_range(entry, camera))
			if not keep and original_in_range(entry, camera):
				avoided += 1
			assert(keep or not any_visible, "A visible grass root was culled")
			assert(keep == entry.grass_in_range(Vector3(x, -200, z)))
			checked += 1
			if not keep:
				skipped += 1
	assert(skipped > 0 and skipped < checked)
	assert(avoided > 0, "Exact roots must reject empty portions of the rectangle")
	# Small movement reuses negative certificates; teleports and returning
	# inside the fade radius must invalidate them geometrically.
	var rng := RandomNumberGenerator.new()
	rng.seed = 145
	var probe := Vector3.ZERO
	var cache_reuses := 0
	for step in range(12000):
		if step % 100 == 0:
			probe = Vector3(rng.randf_range(-30, 50), 0, rng.randf_range(-60, 20))
		else:
			probe += Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15))
		var inside_certificate := entry.grass_empty_radius_squared > 0 and Vector2(probe.x, probe.z).distance_squared_to(entry.grass_empty_center) < entry.grass_empty_radius_squared
		assert(entry.grass_in_range(probe) == roots_in_range(node, roots, probe),
			"Negative cache disagrees with actual roots at %s" % probe)
		if inside_certificate and original_in_range(entry, probe):
			cache_reuses += 1
	assert(cache_reuses > 0, "Movement must exercise the negative cache inside root bounds")
	print("GRASS_EMPTY_CACHE_PASS steps=12000 reused=", cache_reuses)
	# Inclusive fade boundary and points just outside each edge/corner.
	for offset in [Vector2(26, 0), Vector2(26.001, 0),
			Vector2(0, 26), Vector2(0, 26.001), Vector2(18.384777, 18.384777)]:
		for corner in [entry.grass_roots.position, entry.grass_roots.end]:
			for direction in [-1.0, 1.0]:
				var point: Vector2 = corner + offset * direction
				var camera := Vector3(point.x, 0, point.y)
				assert(entry.grass_in_range(camera) == roots_in_range(node, roots, camera))
	# Just inside 26 m from a real root remains included, with the 24 m shader
	# radius unchanged. Exercise the cached hit as the camera crosses the cell.
	for local_root in roots:
		var world_root: Vector3 = node.global_transform * local_root
		var camera := world_root + Vector3(25.999, 0, 0)
		assert(entry.grass_in_range(camera))
	assert(node.multimesh.instance_count == 4)
	var controller := Mobile.new()
	# Use the production 30 m range: it must not override horizontal roots.
	controller.distance_nodes.append(Mobile.DistanceEntry.new(node, node.global_position, 0, 30))
	controller.update_distance_visibility(Vector3(100, 0, 100), Time.get_ticks_usec())
	assert(not node.visible)
	controller.update_distance_visibility(node.global_position, Time.get_ticks_usec())
	assert(node.visible, "Grass must reappear on approach")
	controller.update_distance_visibility(node.global_position + Vector3(0, 40, 0), Time.get_ticks_usec())
	assert(node.visible, "Center height must not override the shader's horizontal fade")
	var edge: Vector3 = node.global_transform * roots[3]
	var outward := (edge - node.global_position).normalized()
	var near_edge := edge + outward * 23.0
	assert(near_edge.distance_to(node.global_position) > 30.0)
	controller.update_distance_visibility(near_edge, Time.get_ticks_usec())
	assert(node.visible, "Visible edge blades must survive the old center cutoff")
	controller.free()
	var ordinary := Mobile.DistanceEntry.new(Node3D.new(), Vector3.ZERO, 0, 30)
	assert(ordinary.grass_in_range(Vector3(1000, 0, 1000)))
	ordinary.node.free()
	node.free()
	# After a miss, approaching the nearest root should use the single-root
	# fast path, including when that root is last in a sparse batch.
	var sparse := MultiMeshInstance3D.new()
	sparse.multimesh = MultiMesh.new()
	sparse.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	sparse.multimesh.mesh = QuadMesh.new()
	sparse.multimesh.instance_count = 4
	var sparse_roots := [Vector3.ZERO, Vector3(100, 0, 100),
		Vector3(0, 0, 100), Vector3(100, 0, 0)]
	for i in range(sparse_roots.size()):
		sparse.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, sparse_roots[i]))
	sparse.set_meta("mobile_animated_grass_fade", true)
	root.add_child(sparse)
	var sparse_entry := Mobile.DistanceEntry.new(sparse, Vector3.ZERO, 0, 30)
	assert(not sparse_entry.grass_in_range(Vector3(73, 0, 10)))
	assert(sparse_entry.grass_near_root == 3, "Miss must retain the closest root for approach")
	for x in range(73, 102):
		var camera := Vector3(x, 0, 10)
		assert(sparse_entry.grass_in_range(camera) == roots_in_range(sparse, sparse_roots, camera))
	assert(sparse_entry.grass_near_root == 3)
	sparse.free()
	print("GRASS_APPROACH_CACHE_PASS")
	print("ANDROID_GRASS_FADE_CULL_PASS positions=%d culled=%d avoided_empty_batches=%d" % [checked, skipped, avoided])
	quit()

func roots_in_range(node: Node3D, roots: Array, camera: Vector3) -> bool:
	for local_root in roots:
		var world_root: Vector3 = node.global_transform * local_root
		if Vector2(camera.x, camera.z).distance_squared_to(Vector2(world_root.x, world_root.z)) <= 26.0 * 26.0:
			return true
	return false

func original_in_range(entry, camera: Vector3) -> bool:
	var x := maxf(maxf(entry.grass_roots.position.x - camera.x,
		camera.x - entry.grass_roots.end.x), 0.0)
	var z := maxf(maxf(entry.grass_roots.position.y - camera.z,
		camera.z - entry.grass_roots.end.y), 0.0)
	return x * x + z * z <= entry.grass_fade_squared
