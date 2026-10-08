extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 600)
	var world := Node3D.new()
	root.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(18, 0, -9))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.36, 0.40)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 0.94)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	for i in range(6):
		var part := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		if i % 2 == 0:
			cone.top_radius = 0.16
			cone.bottom_radius = 2.72
			cone.height = 1.65
			cone.radial_segments = 48
			var steel := ShaderMaterial.new()
			steel.shader = preload("res://shaders/silo_galvanized.gdshader")
			steel.set_shader_parameter("corrugation_strength", 0.0)
			part.material_override = steel
		else:
			cone.top_radius = 0.10
			cone.bottom_radius = 0.46
			cone.height = 0.25
			var paint := StandardMaterial3D.new()
			paint.albedo_color = Color("657571")
			part.material_override = paint
			part.scale = Vector3.ONE * 5.0
		part.mesh = cone
		world.add_child(part)
		part.position = Vector3((i % 3) * 6 - 2, (i / 3) * 4 - 1, 2)
		part.rotation = Vector3(0.25 * i, 0.15 * i, 0.04 * i)
		part.create_trimesh_collision()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4, 6, 22)
	camera.look_at(world.to_global(Vector3(4, 1.5, 2)))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-35, -35, 0)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("before.png")) == OK)
	var measurements: Array[Dictionary] = []
	for child in world.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			if OS.get_environment("CONE_REVIEW_HOOD_ONLY") == "1" and child.material_override is ShaderMaterial:
				continue
			var before: int = child.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3
			var bounds: AABB = child.mesh.get_aabb()
			var collision: Shape3D = child.get_child(0).get_child(0).shape
			child.mesh.rings = 0
			var after: int = child.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3
			assert(after < before)
			assert(child.mesh.get_aabb().is_equal_approx(bounds))
			assert(child.get_child(0).get_child(0).shape == collision)
			measurements.append({"radial_segments": child.mesh.radial_segments, "triangles_before": before, "triangles_after": after})
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("after.png")) == OK)
	var report := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
	report.close()
	print("CONE_RINGS_REVIEW_PASS")
	quit()
