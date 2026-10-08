extends SceneTree

func _initialize() -> void:
	call_deferred("review")

func review() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 720)
	var visuals = load("res://scripts/world_visuals.gd")
	visuals.bake_android_ground = true
	var scene := Node3D.new()
	root.add_child(scene)
	var material = visuals.service_ground_material()
	var original = visuals.excavated_surface(scene, Rect2(-27, 10, 52, 46), material, false, 0.044)
	var trimmed = visuals.excavated_surface(scene, Rect2(-27, 10, 52, 46), material, false, 0.044, visuals.service_ground_regions())
	var before: Array = original.mesh.surface_get_arrays(0)
	var after: Array = trimmed.mesh.surface_get_arrays(0)
	assert(before[Mesh.ARRAY_VERTEX] == after[Mesh.ARRAY_VERTEX])
	assert(before[Mesh.ARRAY_NORMAL] == after[Mesh.ARRAY_NORMAL])
	assert(before[Mesh.ARRAY_TEX_UV] == after[Mesh.ARRAY_TEX_UV])
	assert(after[Mesh.ARRAY_INDEX].size() < before[Mesh.ARRAY_INDEX].size())
	var sun := DirectionalLight3D.new()
	scene.add_child(sun)
	sun.rotation_degrees = Vector3(-34, -142, 0)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 62
	camera.position = Vector3(-1, 60, 33)
	camera.rotation_degrees.x = -90
	camera.current = true
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var images: Array[Image] = []
	for use_trim in [false, true]:
		original.visible = not use_trim
		trimmed.visible = use_trim
		await process_frame
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		images.append(image)
		assert(image.save_png(output.path_join("trimmed.png" if use_trim else "original.png")) == OK)
	var a := images[0].get_data()
	var b := images[1].get_data()
	var absolute_error := 0
	var changed := 0
	for i in range(a.size()):
		absolute_error += absi(int(a[i]) - int(b[i]))
		if a[i] != b[i]:
			changed += 1
	var report := {"original_triangles": before[Mesh.ARRAY_INDEX].size() / 3,
		"trimmed_triangles": after[Mesh.ARRAY_INDEX].size() / 3,
		"identical_vertices_normals_uv": true, "changed_channels": changed,
		"mean_absolute_channel_error": float(absolute_error) / a.size(),
		"scope": "Actual yard mesh, overhead isolated render; not combat performance or full-scene acceptance"}
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	assert(float(absolute_error) / a.size() < 0.1, "Trimming changed visible material")
	quit()
