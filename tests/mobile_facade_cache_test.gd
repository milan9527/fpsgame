extends SceneTree

const Profile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("_run")

func _triangles(arrays: Array) -> Dictionary:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var triangles := {}
	for i in range(0, indices.size(), 3):
		var corners := [indices[i], indices[i + 1], indices[i + 2]]
		if (vertices[corners[1]] - vertices[corners[0]]).cross(vertices[corners[2]] - vertices[corners[0]]) == Vector3.ZERO:
			continue
		var attributes := []
		for corner in corners:
			for channel in range(Mesh.ARRAY_MAX):
				if channel == Mesh.ARRAY_INDEX or arrays[channel] == null:
					continue
				var stride: int = arrays[channel].size() / vertices.size()
				for component in range(stride):
					attributes.append(arrays[channel][corner * stride + component])
		var key := var_to_str(attributes)
		triangles[key] = triangles.get(key, 0) + 1
	return triangles

# Deterministic LRU simulation measures index locality only, not GPU time.
func _misses(indices: PackedInt32Array, capacity: int) -> int:
	var cache: Array[int] = []
	var misses := 0
	for index in indices:
		var position := cache.find(index)
		if position < 0:
			misses += 1
		else:
			cache.remove_at(position)
		cache.push_front(index)
		if cache.size() > capacity:
			cache.pop_back()
	return misses

func _run() -> void:
	# A tiny but nonzero face must survive; only coincident corners disappear.
	var fixture := []
	fixture.resize(Mesh.ARRAY_MAX)
	fixture[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3.ZERO, Vector3.RIGHT, Vector3(0, 0.00000001, 0), Vector3.ZERO])
	fixture[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 3, 1])
	assert(Profile.strip_collapsed_static_triangles(fixture) == 1)
	assert(fixture[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 1, 2]))
	assert(Profile.strip_collapsed_static_triangles(fixture) == 0)
	assert(fixture[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 1, 2]))
	fixture[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 3, 1, 0, 1, 2])
	assert(Profile.strip_collapsed_static_triangles(fixture) == 1)
	assert(fixture[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 1, 2]))
	fixture[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 3, 1])
	assert(Profile.strip_collapsed_static_triangles(fixture) == 0)
	assert(fixture[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 3, 1]))
	var world := Node3D.new()
	root.add_child(world)
	var material := StandardMaterial3D.new()
	var reference := SurfaceTool.new()
	reference.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unoptimized := SurfaceTool.new()
	unoptimized.begin(Mesh.PRIMITIVE_TRIANGLES)
	var originals: Array[MeshInstance3D] = []
	for i in range(3):
		var item := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radial_segments = 32
		shape.rings = 16
		item.mesh = shape
		item.material_override = material
		item.position = Vector3(2 + i * 2, 2, 2)
		world.add_child(item)
		item.add_child(StaticBody3D.new())
		originals.append(item)
		unoptimized.append_from(shape, 0, item.transform)
		var primitive := SurfaceTool.new()
		primitive.create_from(shape, 0)
		primitive.optimize_indices_for_cache()
		# Independent reference filter before transform: translation can round
		# distinct tiny coordinates onto each other, which is not the criterion.
		var expected := primitive.commit_to_arrays()
		var visible_before := _triangles(expected)
		var points: PackedVector3Array = expected[Mesh.ARRAY_VERTEX]
		var kept := PackedInt32Array()
		var indices: PackedInt32Array = expected[Mesh.ARRAY_INDEX]
		for offset in range(0, indices.size(), 3):
			var triangle := indices.slice(offset, offset + 3)
			if points[triangle[0]] != points[triangle[1]] and points[triangle[1]] != points[triangle[2]] and points[triangle[2]] != points[triangle[0]]:
				kept.append_array(triangle)
		expected[Mesh.ARRAY_INDEX] = kept
		assert(_triangles(expected) == visible_before, "Reference filter changed visible triangles")
		var expected_mesh := ArrayMesh.new()
		expected_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, expected)
		reference.append_from(expected_mesh, 0, item.transform)
	var original_arrays := unoptimized.commit().surface_get_arrays(0)
	var before := reference.commit().surface_get_arrays(0)
	assert(Profile.batch_static_meshes(world) == 3)
	var batches := world.find_children("MobileFacadeBatch*", "MeshInstance3D", true, false)
	assert(batches.size() == 1)
	var after: Array = batches[0].mesh.surface_get_arrays(0)
	assert(after[Mesh.ARRAY_INDEX].size() == before[Mesh.ARRAY_INDEX].size())
	var vertex_count: int = before[Mesh.ARRAY_VERTEX].size()
	var compact_count: int = after[Mesh.ARRAY_VERTEX].size()
	assert(compact_count < vertex_count, "Collapsed-face orphan vertices were retained")
	for channel in range(Mesh.ARRAY_MAX):
		if channel == Mesh.ARRAY_INDEX:
			continue
		if before[channel] == null:
			assert(after[channel] == null)
			continue
		var stride: int = before[channel].size() / vertex_count
		assert(after[channel].size() == compact_count * stride)
		for corner in range(before[Mesh.ARRAY_INDEX].size()):
			var old_index: int = before[Mesh.ARRAY_INDEX][corner]
			var new_index: int = after[Mesh.ARRAY_INDEX][corner]
			for component in range(stride):
				assert(before[channel][old_index * stride + component] == after[channel][new_index * stride + component],
					"Indexed triangle attribute/order changed")
	# Every newly fetched vertex within a constituent is adjacent in storage.
	# This checks layout, not a prediction of GPU time.
	var seen := {}
	var discontinuities := 0
	var previous_first := -1
	for index in after[Mesh.ARRAY_INDEX]:
		if seen.has(index):
			continue
		if previous_first >= 0 and index != previous_first + 1:
			discontinuities += 1
		seen[index] = true
		previous_first = index
	assert(discontinuities == 0, "First-use vertex layout is not contiguous")
	assert(seen.size() == compact_count, "Unreferenced attributes remain in the merged buffer")
	assert(_triangles(before) == _triangles(after),
		"Nonzero triangle attributes, corners or winding changed")
	assert(after[Mesh.ARRAY_INDEX].size() < original_arrays[Mesh.ARRAY_INDEX].size())
	assert(batches[0].material_override == material)
	for item in originals:
		assert(item.mesh == null and item.get_child(0) is StaticBody3D)
	var report := {"triangles_before": original_arrays[Mesh.ARRAY_INDEX].size() / 3,
		"triangles_after": after[Mesh.ARRAY_INDEX].size() / 3,
		"first_use_discontinuities": discontinuities, "vertices_before": vertex_count,
		"vertices_after": compact_count}
	for capacity in [16, 24, 32]:
		var previous := _misses(before[Mesh.ARRAY_INDEX], capacity)
		var current := _misses(after[Mesh.ARRAY_INDEX], capacity)
		assert(current < _misses(original_arrays[Mesh.ARRAY_INDEX], capacity), "Cache optimization regressed")
		assert(current <= previous, "Representative primitive cache locality regressed")
		report[str(capacity)] = {"before": previous, "after": current}
	print("MOBILE_FACADE_CACHE_PASS ", JSON.stringify(report))
	world.free()
	quit()
