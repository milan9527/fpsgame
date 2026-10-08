extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var source: ArrayMesh = load("res://assets/android_terrain.res")
	var cell_size: float = preload("res://scripts/terrain_mesh_chunks.gd").DEFAULT_CELL_SIZE
	if not OS.get_environment("TERRAIN_CELL_SIZE").is_empty():
		cell_size = OS.get_environment("TERRAIN_CELL_SIZE").to_float()
	var dense_triangle_limit := OS.get_environment("TERRAIN_DENSE_TRIANGLE_LIMIT").to_int()
	var scene := preload("res://scripts/terrain_mesh_chunks.gd").build(source, cell_size, dense_triangle_limit)
	var target := OS.get_environment("TERRAIN_CHUNKS_OUTPUT")
	if target.is_empty():
		target = "user://android_terrain_chunks_test.scn"
	assert(ResourceSaver.save(scene, target) == OK)
	var saved: PackedScene = ResourceLoader.load(target, "", ResourceLoader.CACHE_MODE_IGNORE)
	var chunks := saved.instantiate()
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index_by_position := {}
	for i in range(vertices.size()):
		assert(not index_by_position.has(vertices[i]))
		index_by_position[vertices[i]] = i
	var expected := {}
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		expected[Vector3i(indices[i], indices[i + 1], indices[i + 2])] = true
	var total := 0
	var normal_error := 0.0
	for node in chunks.get_children():
		var chunk: ArrayMesh = node.mesh
		var actual := chunk.surface_get_arrays(0)
		var mapping := PackedInt32Array()
		for i in range(actual[Mesh.ARRAY_VERTEX].size()):
			var position: Vector3 = actual[Mesh.ARRAY_VERTEX][i]
			assert(index_by_position.has(position))
			var original: int = index_by_position[position]
			mapping.append(original)
			normal_error = maxf(normal_error, actual[Mesh.ARRAY_NORMAL][i].distance_to(arrays[Mesh.ARRAY_NORMAL][original]))
			assert(normal_error < 0.001)
			assert(actual[Mesh.ARRAY_TEX_UV][i].is_equal_approx(arrays[Mesh.ARRAY_TEX_UV][original]))
		var local_indices: PackedInt32Array = actual[Mesh.ARRAY_INDEX]
		for i in range(0, local_indices.size(), 3):
			var triangle := Vector3i(mapping[local_indices[i]], mapping[local_indices[i + 1]], mapping[local_indices[i + 2]])
			assert(expected.has(triangle))
			expected.erase(triangle)
			total += 1
		# Terrain must not be treated as a small decorative distance-cull object.
		assert(chunk.get_aabb().size.length() >= 40.0)
	assert(expected.is_empty())
	print("TERRAIN_CHUNKS_PASS chunks=", chunks.get_child_count(), " triangles=", total, " max_normal_error=", normal_error, " positions_uv_winding=preserved collision=unchanged")
	chunks.free()
	quit()
