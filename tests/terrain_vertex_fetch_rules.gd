extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func block_transitions(indices: PackedInt32Array) -> int:
	var previous := -1
	var transitions := 0
	for index in indices:
		var block := index / 16
		if block != previous:
			transitions += 1
			previous = block
	return transitions

func run() -> void:
	# LOD-only vertices must survive compaction; unused vertices must not.
	var fixture := []
	fixture.resize(Mesh.ARRAY_MAX)
	fixture[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.ONE])
	fixture[Mesh.ARRAY_TANGENT] = PackedFloat32Array([
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
		12, 13, 14, 15, 16, 17, 18, 19])
	fixture[Mesh.ARRAY_INDEX] = PackedInt32Array([2, 0, 1])
	var fixture_lods := {10.0: PackedInt32Array([3, 2, 0])}
	preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(fixture, fixture_lods, false)
	assert(fixture[Mesh.ARRAY_VERTEX] == PackedVector3Array([
		Vector3.UP, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK]))
	assert(fixture[Mesh.ARRAY_TANGENT] == PackedFloat32Array([
		8, 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7, 12, 13, 14, 15]))
	assert(fixture[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 1, 2]))
	assert(fixture_lods[10.0] == PackedInt32Array([3, 0, 1]))
	var source: ArrayMesh = load("res://assets/android_terrain.res")
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(0))
	importer.generate_lods(60.0, 0.0, [])
	var mesh := importer.get_mesh()
	var optimizer := SurfaceTool.new()
	optimizer.create_from(mesh, 0)
	optimizer.optimize_indices_for_cache()
	var before := importer.get_surface_arrays(0)
	before[Mesh.ARRAY_INDEX] = optimizer.commit_to_arrays()[Mesh.ARRAY_INDEX]
	var arrays := before.duplicate(true)
	var lods := {}
	for lod in range(importer.get_surface_lod_count(0)):
		lods[importer.get_surface_lod_size(0, lod)] = importer.get_surface_lod_indices(0, lod)
	var original_lods := lods.duplicate(true)
	preload("res://scripts/terrain_mesh_lod.gd").reorder_vertex_fetch(arrays, lods)
	var by_position := {}
	for i in range(before[Mesh.ARRAY_VERTEX].size()):
		var position: Vector3 = before[Mesh.ARRAY_VERTEX][i]
		assert(not by_position.has(position))
		by_position[position] = i
	var inverse := PackedInt32Array()
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	assert(count == before[Mesh.ARRAY_VERTEX].size())
	for i in range(count):
		var old: int = by_position[arrays[Mesh.ARRAY_VERTEX][i]]
		inverse.append(old)
		for slot in range(Mesh.ARRAY_MAX):
			if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
				continue
			var stride: int = arrays[slot].size() / count
			for component in range(stride):
				assert(arrays[slot][i * stride + component] == before[slot][old * stride + component])
	var streams := [{"before":before[Mesh.ARRAY_INDEX], "after":arrays[Mesh.ARRAY_INDEX]}]
	assert(lods.keys() == original_lods.keys())
	for threshold in lods:
		streams.append({"before":original_lods[threshold], "after":lods[threshold]})
	var indices_checked := 0
	for stream in streams:
		assert(stream.before.size() == stream.after.size())
		for i in range(stream.before.size()):
			assert(inverse[stream.after[i]] == stream.before[i])
			indices_checked += 1
	var result := {
		"vertices":count, "lods":lods.size(), "indices_checked":indices_checked,
		"attributes_and_oriented_triangles_exact":true,
		"logical_16_vertex_block_transitions_before":block_transitions(before[Mesh.ARRAY_INDEX]),
		"logical_16_vertex_block_transitions_after":block_transitions(arrays[Mesh.ARRAY_INDEX]),
		"scope":"Index locality proxy only; not GPU cache misses or Android FPS."
	}
	print("TERRAIN_VERTEX_FETCH_PASS ", JSON.stringify(result))
	quit()
