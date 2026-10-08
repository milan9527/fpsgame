extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 640)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	var mobile = load("res://scripts/mobile_performance.gd")
	var mesh := SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 2
	mesh.radius = 0.5
	mesh.height = 1.0
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.98
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = 256
	var rng := RandomNumberGenerator.new()
	rng.seed = 13781
	for i in range(mm.instance_count):
		var size := rng.randf_range(0.06, 0.19)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.22, 0.45), size))
		mm.set_instance_transform(i, Transform3D(basis, Vector3((i % 16 - 8) * 0.2, 0, (i / 16 - 8) * 0.2)))
		mm.set_instance_color(i, Color(rng.randf_range(0.2, 0.5), 0.3, 0.2))
	var groups := []
	for optimized in [false, true]:
		var group := Node3D.new()
		root.add_child(group)
		groups.append(group)
		for cell in range(2):
			var node := MultiMeshInstance3D.new()
			node.name = "GroundLitterCell%d" % cell
			node.multimesh = mm
			node.material_override = material
			node.position.x = cell * 3.2
			group.add_child(node)
		if optimized:
			mobile.configure_world(group)
	var optimized_mm: MultiMesh = groups[1].get_child(0).multimesh
	assert(optimized_mm != mm)
	assert(mm.mesh == mesh)
	assert(optimized_mm.mesh == groups[1].get_child(1).multimesh.mesh)
	assert(optimized_mm.buffer == mm.buffer)
	assert(optimized_mm.instance_count == mm.instance_count)
	assert(optimized_mm.visible_instance_count == mm.visible_instance_count)
	assert(optimized_mm.get_aabb().is_equal_approx(mm.get_aabb()))
	var before: int = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	var after: int = optimized_mm.mesh.surface_get_array_index_len(0) / 3
	assert(before == 30 and after == 20)
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
	var views := []
	for eye in [Vector3(1, 1, 3), Vector3(1, 0.15, 2), Vector3(3, 4, 5), Vector3(1, 8, 12)]:
		camera.position = eye
		camera.look_at(Vector3(1, 0, 0))
		var images := []
		for variant in range(2):
			groups[0].visible = variant == 0
			groups[1].visible = variant == 1
			await process_frame
			RenderingServer.force_draw(false)
			var image := root.get_texture().get_image()
			assert(image.save_png(output.path_join("view-%s-%s.png" % [views.size(), variant])) == OK)
			images.append(image)
		views.append({"eye": str(eye), "pixel_identical": images[0].get_data() == images[1].get_data()})
	var report := {"triangles_per_pebble_before": before, "triangles_per_pebble_after": after,
		"fixture_instances": 512, "instance_buffers_and_bounds_preserved": true,
		"shared_mesh_preserved": true, "views": views,
		"scope": "OpenGL/Xvfb visual regression only; not Android performance acceptance"}
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for view in views:
		assert(view.pixel_identical, "Inspect image differences")
	print("GROUND_LITTER_REVIEW_PASS ", JSON.stringify(report))
	quit()
