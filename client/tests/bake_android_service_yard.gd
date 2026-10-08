extends SceneTree

# Offline, narrowly scoped bake: never construct the world or bake other assets.
# Require an explicit NEW destination to preserve previous candidate snapshots.
func _initialize() -> void:
	call_deferred("_run")

func triangles(arrays: Array) -> Dictionary:
	var result := {}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0, indices.size(), 3):
		var points := [vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]]]
		var keys := [str(points), str([points[1], points[2], points[0]]), str([points[2], points[0], points[1]])]
		keys.sort()
		result[keys[0]] = result.get(keys[0], 0) + 1
	return result

func _run() -> void:
	var destination := OS.get_environment("ANDROID_YARD_OUTPUT")
	assert(not destination.is_empty() and not FileAccess.file_exists(destination),
		"ANDROID_YARD_OUTPUT must name a new .res file.")
	assert(destination.ends_with(".res"))
	assert(RenderingServer.get_rendering_device() != null or DisplayServer.get_name() != "headless",
		"Use a real renderer, e.g. Xvfb with gl_compatibility.")
	var visuals := GDScript.new()
	visuals.source_code = FileAccess.get_file_as_string("res://scripts/world_visuals.gd").replace('OS.has_feature("android")', "true")
	assert(visuals.reload() == OK)
	var holder := Node3D.new()
	root.add_child(holder)
	var yard: MeshInstance3D = visuals.excavated_surface(holder, Rect2(-27, 10, 52, 46),
		null, false, 0.044, visuals.service_ground_regions())
	var source: Array = yard.mesh.surface_get_arrays(0)
	var candidate: ArrayMesh = load("res://scripts/terrain_mesh_lod.gd").build(yard.mesh)
	assert(ResourceSaver.save(candidate, destination, ResourceSaver.FLAG_COMPRESS) == OK)
	var restored: ArrayMesh = ResourceLoader.load(destination, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert(restored.get_surface_count() == 1)
	var actual := restored.surface_get_arrays(0)
	assert(triangles(source) == triangles(actual), "Base oriented triangle multiset changed.")
	var by_position := {}
	for i in range(source[Mesh.ARRAY_VERTEX].size()):
		var position: Vector3 = source[Mesh.ARRAY_VERTEX][i]
		assert(not by_position.has(position), "Expected unique grid vertices.")
		by_position[position] = i
	assert(actual[Mesh.ARRAY_VERTEX].size() == by_position.size())
	var max_normal_error := 0.0
	for i in range(actual[Mesh.ARRAY_VERTEX].size()):
		var original: int = by_position[actual[Mesh.ARRAY_VERTEX][i]]
		assert(actual[Mesh.ARRAY_TEX_UV][i] == source[Mesh.ARRAY_TEX_UV][original])
		max_normal_error = maxf(max_normal_error,
			actual[Mesh.ARRAY_NORMAL][i].distance_to(source[Mesh.ARRAY_NORMAL][original]))
	assert(max_normal_error <= 0.0002, "Normal encoding drift exceeds terrain tolerance.")
	# Inspect serialized index buffers, not merely the in-memory importer.
	var surfaces: Array = restored.get("_surfaces")
	assert(surfaces.size() == 1 and not surfaces[0].get("lods", []).is_empty())
	print(JSON.stringify({"destination": destination, "vertices": by_position.size(),
		"base_triangles": source[Mesh.ARRAY_INDEX].size() / 3,
		"oriented_topology_equal": true, "uv_equal": true,
		"max_normal_error": max_normal_error, "serialized_lod_entries": surfaces[0]["lods"].size()}))
	holder.queue_free()
	quit()
