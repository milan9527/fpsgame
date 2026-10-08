extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func _initialize() -> void:
	call_deferred("_run")

func _triangles(indices: PackedInt32Array) -> Dictionary:
	var triangles := {}
	for i in range(0, indices.size(), 3):
		var key := Vector3i(indices[i], indices[i + 1], indices[i + 2])
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

func _blocks(indices: PackedInt32Array) -> int:
	var previous := -1
	var transitions := 0
	for index in indices:
		var block_id: int = index / 16
		if block_id != previous:
			transitions += 1
			previous = block_id
	return transitions

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var report := []
	for clipped in [false, true]:
		var regions: Array[Rect2] = []
		if clipped:
			regions.assign(Visuals.service_ground_regions())
		var material := StandardMaterial3D.new()
		var item := Visuals.excavated_surface(world, Rect2(-27, 10, 52, 46), material, false, 0.044, regions)
		var before: Array = item.mesh.surface_get_arrays(0)
		var after := Visuals.road_surface_cache_order(before)
		var old_positions := {}
		for index in range(before[Mesh.ARRAY_VERTEX].size()):
			old_positions[before[Mesh.ARRAY_VERTEX][index]] = index
		assert(old_positions.size() == before[Mesh.ARRAY_VERTEX].size())
		var inverse := PackedInt32Array()
		for position in after[Mesh.ARRAY_VERTEX]:
			assert(old_positions.has(position))
			inverse.append(old_positions[position])
		for attribute in range(Mesh.ARRAY_MAX):
			if attribute == Mesh.ARRAY_INDEX or before[attribute] == null:
				continue
			var stride: int = before[attribute].size() / old_positions.size()
			assert(after[attribute].size() == inverse.size() * stride)
			for index in range(inverse.size()):
				for component in range(stride):
					assert(before[attribute][inverse[index] * stride + component] == after[attribute][index * stride + component], "Road attribute changed")
		var restored := PackedInt32Array()
		for index in after[Mesh.ARRAY_INDEX]:
			restored.append(inverse[index])
		assert(_triangles(before[Mesh.ARRAY_INDEX]) == _triangles(restored))
		var referenced := {}
		for index in after[Mesh.ARRAY_INDEX]:
			referenced[index] = true
		assert(referenced.size() == inverse.size(), "Unused road vertices retained")
		if clipped:
			assert(inverse.size() < old_positions.size())
		else:
			assert(inverse.size() == old_positions.size())
		# Compare the SAME optimized triangle order with old vs new vertex IDs.
		# Logical block transitions are a locality proxy, not hardware timings.
		var old_blocks := _blocks(restored)
		var new_blocks := _blocks(after[Mesh.ARRAY_INDEX])
		assert(new_blocks < old_blocks, "Road vertex fetch locality regressed")
		assert(item.material_override == material and item.get_child_count() == 0)
		var counts := {}
		for capacity in [16, 24, 32]:
			var old_count := _misses(before[Mesh.ARRAY_INDEX], capacity)
			var new_count := _misses(after[Mesh.ARRAY_INDEX], capacity)
			assert(new_count < old_count, "Road cache locality regressed")
			counts[str(capacity)] = {"before": old_count, "after": new_count}
		report.append({"clipped": clipped, "vertices_before": old_positions.size(), "vertices_after": inverse.size(), "triangles": before[Mesh.ARRAY_INDEX].size() / 3, "lru_misses": counts, "logical_16_vertex_block_transitions": {"before": old_blocks, "after": new_blocks}})
	print("MOBILE_ROAD_CACHE_PASS ", JSON.stringify(report))
	world.free()
	quit()
