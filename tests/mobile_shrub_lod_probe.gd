extends SceneTree

func cache_misses(indices: PackedInt32Array, capacity: int) -> int:
	var cache: Array[int] = []
	var count := 0
	for index in indices:
		if cache.has(index):
			cache.erase(index)
		else:
			count += 1
		cache.push_front(index)
		if cache.size() > capacity:
			cache.pop_back()
	return count

func oriented_triangles(indices: PackedInt32Array) -> Dictionary:
	var result := {}
	for i in range(0, indices.size(), 3):
		var key := Vector3i(indices[i], indices[i + 1], indices[i + 2])
		result[key] = result.get(key, 0) + 1
	return result

# Actual OpenGL submission counts, not source triangles or Android FPS.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1440, 900)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var rows := []
	var topology := []
	for asset in ["verge_shrub_palette_mobile", "verge_fine_shrub_palette_mobile"]:
		var scene: Node3D = load("res://assets/realism/" + asset + ".glb").instantiate()
		var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var single := MeshInstance3D.new()
		single.mesh = source.mesh
		var weld := OS.get_environment("SHRUB_LOD_WELD") == "1"
		var reorder := OS.get_environment("SHRUB_LOD_CACHE") == "1"
		if OS.get_environment("SHRUB_LOD_RELAX_NORMALS") == "1" or weld or reorder:
			var importer := ImporterMesh.new()
			for surface in range(source.mesh.get_surface_count()):
				var arrays: Array = source.mesh.surface_get_arrays(surface)
				var original_vertices: int = arrays[Mesh.ARRAY_VERTEX].size()
				if reorder:
					var optimizer := SurfaceTool.new()
					optimizer.create_from(source.mesh, surface)
					optimizer.optimize_indices_for_cache()
					var ordered := optimizer.commit_to_arrays()
					# This experiment must only change index submission order.
					for attribute in range(Mesh.ARRAY_MAX):
						if attribute != Mesh.ARRAY_INDEX:
							assert(arrays[attribute] == ordered[attribute])
					assert(oriented_triangles(arrays[Mesh.ARRAY_INDEX]) == oriented_triangles(ordered[Mesh.ARRAY_INDEX]))
					var metrics := []
					for capacity in [8, 16, 24, 32]:
						metrics.append({"capacity": capacity,
							"before_misses": cache_misses(arrays[Mesh.ARRAY_INDEX], capacity),
							"after_misses": cache_misses(ordered[Mesh.ARRAY_INDEX], capacity)})
					topology.append({"asset": asset, "surface": surface, "cache_model": "LRU estimate, not GPU timing", "metrics": metrics})
					arrays = ordered
				if weld:
					var tool := SurfaceTool.new()
					tool.create_from(source.mesh, surface)
					tool.deindex()
					tool.index()
					arrays = tool.commit_to_arrays()
					# Verify every triangle corner retains every imported attribute.
					var original: Array = source.mesh.surface_get_arrays(surface)
					for corner in range(original[Mesh.ARRAY_INDEX].size()):
						var before: int = original[Mesh.ARRAY_INDEX][corner]
						var after: int = arrays[Mesh.ARRAY_INDEX][corner]
						for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
							if original[attribute] == null or original[attribute].is_empty():
								continue
							var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
							for component in range(stride):
								assert(original[attribute][before * stride + component] == arrays[attribute][after * stride + component])
				topology.append({"asset": asset, "surface": surface,
					"original_vertices": original_vertices,
					"candidate_vertices": arrays[Mesh.ARRAY_VERTEX].size()})
				importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays,
					[], {}, source.mesh.surface_get_material(surface))
			# Candidate only: preserve base geometry and regenerate distant LODs
			# with a wider normal merge angle. Never write imported resources.
			importer.generate_lods(180.0, 0.0, [])
			single.mesh = importer.get_mesh()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = single.mesh
		batch.multimesh.instance_count = 1
		batch.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
		root.add_child(single)
		root.add_child(batch)
		var center := single.mesh.get_aabb().get_center()
		for distance in [5.0, 15.0, 30.0, 60.0, 100.0]:
			camera.position = center + Vector3(0, 0, distance)
			camera.look_at(center)
			for threshold in [0.0, 4.0]:
				root.mesh_lod_threshold = threshold
				for mode in ["single", "batch"]:
					single.visible = mode == "single"
					batch.visible = mode == "batch"
					for frame in range(4):
						await process_frame
					await RenderingServer.frame_post_draw
					rows.append({"asset": asset, "distance": distance, "threshold": threshold,
						"mode": mode,
						"primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
						"draws": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
		single.free()
		batch.free()
		scene.free()
	var output := OS.get_environment("SHRUB_LOD_OUTPUT")
	assert(not output.is_empty())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Isolated mobile asset OpenGL submission probe; not Android performance acceptance", "topology": topology, "rows": rows}, "\t"))
	file.close()
	print("MOBILE_SHRUB_LOD_PROBE_PASS")
	quit()
