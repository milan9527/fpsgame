extends RefCounted

# Retain the authored vertices, normals, UVs and full-resolution surface.
# Only additional render index buffers are simplified; physics keeps its
# independently baked full-resolution shape.
static func build(source: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in range(source.get_surface_count()):
		importer.add_surface(
			source.surface_get_primitive_type(surface),
			source.surface_get_arrays(surface), [], {},
			source.surface_get_material(surface),
			source.surface_get_name(surface))
	importer.generate_lods(60.0, 0.0, [])
	var generated := importer.get_mesh()
	var optimized := ArrayMesh.new()
	for surface in range(generated.get_surface_count()):
		# Use the importer's arrays, avoiding an extra packed-normal round trip.
		var arrays := importer.get_surface_arrays(surface)
		# The baked grid is ordered in long rows, which evicts shared vertices
		# before the next row reaches them. Reorder triangles offline so nearby
		# triangles reuse the GPU vertex cache. Copy only the indices back:
		# SurfaceTool's attribute conversion must not change authored shading.
		var cache_optimizer := SurfaceTool.new()
		cache_optimizer.create_from(generated, surface)
		cache_optimizer.optimize_indices_for_cache()
		arrays[Mesh.ARRAY_INDEX] = cache_optimizer.commit_to_arrays()[Mesh.ARRAY_INDEX]
		# Generate LODs before reordering so simplification and its thresholds
		# stay deterministic relative to the previous terrain bake.
		var lods := {}
		for lod in range(importer.get_surface_lod_count(surface)):
			var lod_arrays := arrays.duplicate()
			lod_arrays[Mesh.ARRAY_INDEX] = importer.get_surface_lod_indices(surface, lod)
			var lod_mesh := ArrayMesh.new()
			lod_mesh.add_surface_from_arrays(generated.surface_get_primitive_type(surface), lod_arrays)
			var lod_optimizer := SurfaceTool.new()
			lod_optimizer.create_from(lod_mesh, 0)
			lod_optimizer.optimize_indices_for_cache()
			# Preserve every LOD triangle and its threshold; change only draw
			# order to reuse transformed vertices in the GPU's post-transform cache.
			lods[importer.get_surface_lod_size(surface, lod)] = lod_optimizer.commit_to_arrays()[Mesh.ARRAY_INDEX]
		reorder_vertex_fetch(arrays, lods)
		optimized.add_surface_from_arrays(generated.surface_get_primitive_type(surface), arrays, [], lods)
		optimized.surface_set_material(surface, generated.surface_get_material(surface))
		optimized.surface_set_name(surface, generated.surface_get_name(surface))
	return optimized

static func reorder_vertex_fetch(arrays: Array, lods: Dictionary, retain_unused: bool = true) -> void:
	# Lay out vertices in first-use order after triangle-cache optimization.
	# Remap every LOD through the same permutation; optionally drop orphans.
	# Referenced attributes, triangles, and simplification thresholds stay exact.
	# An unindexed surface uses every vertex in its original triangle order.
	if arrays[Mesh.ARRAY_INDEX] == null or arrays[Mesh.ARRAY_INDEX].is_empty():
		return
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	var mapping := PackedInt32Array()
	mapping.resize(count)
	mapping.fill(-1)
	var order := PackedInt32Array()
	for index in arrays[Mesh.ARRAY_INDEX]:
		if mapping[index] < 0:
			mapping[index] = order.size()
			order.append(index)
	# A clipped presentation mesh can drop vertices no index buffer uses.
	# Include every LOD reference before compacting, even when absent in base.
	if not retain_unused:
		for threshold in lods:
			for index in lods[threshold]:
				if mapping[index] < 0:
					mapping[index] = order.size()
					order.append(index)
	if retain_unused:
		for index in range(count):
			if mapping[index] < 0:
				mapping[index] = order.size()
				order.append(index)
	for slot in range(Mesh.ARRAY_MAX):
		if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
			continue
		assert(arrays[slot].size() % count == 0)
		var stride: int = arrays[slot].size() / count
		var reordered = arrays[slot].duplicate()
		reordered.resize(order.size() * stride)
		for index in range(order.size()):
			for component in range(stride):
				reordered[index * stride + component] = arrays[slot][order[index] * stride + component]
		arrays[slot] = reordered
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in range(indices.size()):
		indices[index] = mapping[indices[index]]
	arrays[Mesh.ARRAY_INDEX] = indices
	for threshold in lods:
		var lod_indices: PackedInt32Array = lods[threshold]
		for index in range(lod_indices.size()):
			lod_indices[index] = mapping[lod_indices[index]]
		lods[threshold] = lod_indices
