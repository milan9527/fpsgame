extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func visible_faces(mesh: Mesh) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var faces := {}
	for i in range(0, v.size(), 3):
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).length_squared() <= 1e-14:
			continue
		var face := []
		for j in range(3):
			face.append([v[i+j], arrays[Mesh.ARRAY_NORMAL][i+j], arrays[Mesh.ARRAY_TEX_UV][i+j]])
		faces[face] = faces.get(face, 0) + 1
	return faces

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	root.size = Vector2i(960, 640)
	var text := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var start := text.find("\tvar source := SphereMesh.new()", text.find("static func repair_apron_drainage"))
	var end := text.find("\tvar stones := MultiMesh.new()", start)
	assert(start > 0 and end > start)
	var source := "extends RefCounted\nstatic func mesh():\n" + text.substr(start, end-start) + "\treturn stone_mesh\n"
	var meshes := []
	var groups := []
	for enabled in [false, true]:
		var script := GDScript.new()
		script.source_code = source.replace('OS.has_feature("android")', str(enabled))
		assert(script.reload() == OK)
		var mesh: ArrayMesh = script.mesh()
		meshes.append(mesh)
		var group := Node3D.new()
		root.add_child(group)
		groups.append(group)
		var rng := RandomNumberGenerator.new()
		rng.seed = 226071
		for i in range(48):
			var stone := MeshInstance3D.new()
			stone.mesh = mesh
			stone.position = Vector3((i % 8 - 4) * 0.12, 0, (i / 8 - 3) * 0.12)
			stone.rotation = Vector3(rng.randf(), rng.randf()*TAU, rng.randf())
			var size := rng.randf_range(0.025, 0.095)
			stone.scale = Vector3(size, size*0.38, size*rng.randf_range(0.65, 1.4))
			group.add_child(stone)
	assert(visible_faces(meshes[0]) == visible_faces(meshes[1]), "Visible position, normal, UV or winding changed")
	var before: int = meshes[0].surface_get_array_len(0)
	var after: int = meshes[1].surface_get_array_len(0)
	assert(before == 168 and after == 126)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -142, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var report := []
	for eye in [Vector3(0.2,0.3,0.6), Vector3(0.8,1.6,1.8), Vector3(0.1,0.04,0.5), Vector3(1,1.6,5)]:
		camera.position = eye
		camera.look_at(Vector3.ZERO)
		var images := []
		for variant in range(2):
			groups[0].visible = variant == 0
			groups[1].visible = variant == 1
			await process_frame
			RenderingServer.force_draw(false)
			var image := root.get_texture().get_image()
			assert(image.save_png(output.path_join("view-%s-%s.png" % [report.size(), variant])) == OK)
			images.append(image)
		var identical: bool = images[0].get_data() == images[1].get_data()
		report.append({"eye": str(eye), "pixel_identical": identical})
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"before_triangles": before / 3, "after_triangles": after / 3,
		"instances": 1960, "visible_face_attributes_identical": true, "views": report,
		"scope": "Real OpenGL/Xvfb; Android branch simulation, not device acceptance"}, "\t"))
	file.close()
	for view in report:
		assert(view.pixel_identical, "Render changed; inspect saved images")
	print("GRAVEL_DEGENERATE_REVIEW_PASS triangles=56->42 vertices=168->126 four_views_pixel_identical=true")
	quit()
