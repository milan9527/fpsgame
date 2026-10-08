extends SceneTree

const Mobile = preload("res://scripts/mobile_performance.gd")
const Fetch = preload("res://scripts/terrain_mesh_lod.gd")

func _initialize() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3.ZERO, Vector3.RIGHT, Vector3.UP,
		Vector3.UP, Vector3.RIGHT, Vector3.ONE])
	# One shared corner has a UV seam; only the other can be merged.
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2.ZERO, Vector2.RIGHT, Vector2.UP,
		Vector2.ONE, Vector2.RIGHT, Vector2.ONE])
	for empty_indices in [null, PackedInt32Array()]:
		arrays[Mesh.ARRAY_INDEX] = empty_indices
		var untouched := arrays.duplicate(true)
		assert(Mobile.strip_collapsed_static_triangles(arrays) == 0)
		Fetch.reorder_vertex_fetch(arrays, {}, false)
		assert(arrays == untouched, "Unindexed vertex order must stay intact")
		# Godot's surface constructor requires null for absent indices.
		arrays[Mesh.ARRAY_INDEX] = null
		var source := ArrayMesh.new()
		source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		source.surface_set_material(0, material)
		var optimized := Mobile.optimize_static_surface(source)
		var output := optimized.surface_get_arrays(0)
		assert(output[Mesh.ARRAY_INDEX].size() == 6)
		assert(output[Mesh.ARRAY_VERTEX].size() == 5, "Merge duplicates, retain UV seams")
		assert(optimized.surface_get_material(0) == material)
		assert(optimized.get_aabb() == source.get_aabb())
		var original_triangles := []
		var optimized_triangles := []
		for start in [0, 3]:
			var original_triangle := []
			var optimized_triangle := []
			for corner in range(3):
				var original_index: int = start + corner
				var output_index: int = output[Mesh.ARRAY_INDEX][original_index]
				original_triangle.append([arrays[Mesh.ARRAY_VERTEX][original_index], arrays[Mesh.ARRAY_TEX_UV][original_index]])
				optimized_triangle.append([output[Mesh.ARRAY_VERTEX][output_index], output[Mesh.ARRAY_TEX_UV][output_index]])
			original_triangles.append(original_triangle)
			optimized_triangles.append(optimized_triangle)
		for triangle in original_triangles:
			assert(triangle in optimized_triangles, "Preserve winding, positions and UVs")
	print("STATIC_UNINDEXED_SURFACE_PASS")
	quit()
