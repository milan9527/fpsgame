extends SceneTree

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	root.size = Vector2i(1280, 720)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var original: ArrayMesh = load("res://assets/android_terrain.res")
	var reduced: ArrayMesh = load("res://scripts/terrain_mesh_lod.gd").build(original)
	assert(original.get_surface_count() == reduced.get_surface_count())
	for surface in range(original.get_surface_count()):
		var before := original.surface_get_arrays(surface)
		var after := reduced.surface_get_arrays(surface)
		for attribute in range(Mesh.ARRAY_MAX):
			if attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
				# Packed normal/tangent encoding introduces quantization on reimport.
				assert(before[attribute].size() == after[attribute].size())
				var largest_error := 0.0
				for index in range(before[attribute].size()):
					var difference = before[attribute][index] - after[attribute][index]
					largest_error = maxf(largest_error, difference.length() if difference is Vector3 else absf(difference))
				print("TERRAIN_ATTRIBUTE_ERROR attribute=", attribute, " max=", largest_error)
				assert(largest_error < 0.0002, "Normal/tangent changed beyond packing precision")
			else:
				assert(before[attribute] == after[attribute], "Authored surface changed")
	assert(original.create_trimesh_shape().get_faces() == reduced.create_trimesh_shape().get_faces())
	# Verify LOD buffers survive serialization used by the Android export.
	var saved := output.path_join("terrain-lod.res")
	assert(ResourceSaver.save(reduced, saved) == OK)
	reduced = ResourceLoader.load(saved, "", ResourceLoader.CACHE_MODE_IGNORE)
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := MeshInstance3D.new()
	var visuals = load("res://scripts/world_visuals.gd")
	visuals.bake_android_ground = true
	terrain.material_override = visuals.meadow_surface()
	scene.add_child(terrain)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -142, 0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	camera.far = 500
	var results: Array = []
	for view in [
		{"name":"spawn", "position":Vector3(17,1.65,50), "target":Vector3(-1,2.2,66)},
		{"name":"road", "position":Vector3(2,1.6,61), "target":Vector3(0,3.2,-85)},
		{"name":"yard", "position":Vector3(19,1.65,48), "target":Vector3(17,0,40)},
		{"name":"crossing", "position":Vector3(7,5,8), "target":Vector3.ZERO},
		{"name":"distant", "position":Vector3(0,80,250), "target":Vector3.ZERO}]:
		camera.position = view.position
		camera.look_at(view.target)
		var counts: Dictionary = {}
		for mode in ["original", "lod"]:
			terrain.mesh = original if mode == "original" else reduced
			for frame in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			counts[mode] = root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
			assert(root.get_texture().get_image().save_png(output.path_join(view.name + "-" + mode + ".png")) == OK)
		assert(counts.lod < counts.original, "LOD did not activate")
		results.append({"view":view.name, "primitives":counts})
	var report := {"positions_uv_indices_unchanged":true, "normal_tangent_error_below":0.0002, "collision_faces_unchanged":true, "views":results, "scope":"isolated terrain rendering; not Android FPS or full world acceptance"}
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TERRAIN_LOD_REVIEW_PASS ", JSON.stringify(report))
	scene.queue_free()
	await process_frame
	quit()
