extends RefCounted

# Partition complete triangles, retaining authored positions/normals/UVs at
# shared edges. Generate LODs after partitioning so open chunk borders remain
# boundaries of the simplifier. Physics continues to use the original mesh.
# Align the grid to the terrain bounds to avoid narrow edge chunks.
# 48 m keeps road submission below the 60 m grid while reducing the 40 m
# grid's distant LOD and batch overhead. Validate FPS on Android separately.
# Keep chunks larger than the decorative-prop distance-culling threshold.
const DEFAULT_CELL_SIZE := 48.0

static func build(source: ArrayMesh, cell_size: float = DEFAULT_CELL_SIZE, dense_triangle_limit: int = 0) -> PackedScene:
	assert(cell_size > 0.0)
	assert(dense_triangle_limit >= 0)
	var root := Node3D.new()
	root.name = "TerrainChunks"
	var origin := source.get_aabb().position
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var groups := {}
		for start in range(0, indices.size(), 3):
			var center := (vertices[indices[start]] + vertices[indices[start + 1]] + vertices[indices[start + 2]]) / 3.0
			var cell := Vector2i(floori((center.x - origin.x) / cell_size), floori((center.z - origin.z) / cell_size))
			if not groups.has(cell):
				groups[cell] = PackedInt32Array()
			for corner in range(3):
				groups[cell].append(indices[start + corner])
		# Optional offline experiment: split dense cells into Z strips.
		# Disabled in production: complete-scene yard measurements increased
		# both primitives and draws, despite isolated terrain improvements.
		# Keep the experiment available for paired Android measurements.
		var partitions := {}
		for cell in groups:
			var name := "Terrain_%s_%s_%s" % [surface, cell.x + 3, cell.y + 3]
			var grouped: PackedInt32Array = groups[cell]
			if dense_triangle_limit == 0 or grouped.size() <= dense_triangle_limit * 3:
				partitions[name] = grouped
				continue
			var midpoint: float = origin.z + (cell.y + 0.5) * cell_size
			for start in range(0, grouped.size(), 3):
				var center_z: float = (vertices[grouped[start]].z + vertices[grouped[start + 1]].z + vertices[grouped[start + 2]].z) / 3.0
				var strip_name := name + ("_South" if center_z < midpoint else "_North")
				if not partitions.has(strip_name):
					partitions[strip_name] = PackedInt32Array()
				for corner in range(3):
					partitions[strip_name].append(grouped[start + corner])
		for partition_name in partitions:
			var remap := {}
			var chunk_arrays := arrays.duplicate(true)
			for slot in range(Mesh.ARRAY_MAX):
				if chunk_arrays[slot] != null:
					chunk_arrays[slot].resize(0)
			for old_index in partitions[partition_name]:
				if not remap.has(old_index):
					remap[old_index] = remap.size()
					for slot in range(Mesh.ARRAY_MAX):
						if slot == Mesh.ARRAY_INDEX or arrays[slot] == null:
							continue
						var stride: int = arrays[slot].size() / vertices.size()
						for component in range(stride):
							chunk_arrays[slot].append(arrays[slot][old_index * stride + component])
				chunk_arrays[Mesh.ARRAY_INDEX].append(remap[old_index])
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, chunk_arrays)
			mesh.surface_set_material(0, source.surface_get_material(surface))
			var node := MeshInstance3D.new()
			node.name = partition_name
			node.mesh = preload("res://scripts/terrain_mesh_lod.gd").build(mesh)
			root.add_child(node)
			node.owner = root
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	root.free()
	return packed
