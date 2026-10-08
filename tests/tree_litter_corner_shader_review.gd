extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	var baseline := Shader.new()
	baseline.code = FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	assert(not baseline.code.is_empty())
	var candidate := load("res://shaders/tree_litter_mobile.gdshader")
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.colors = PackedColorArray([Color(0.3, 0.2, 0.1), Color(0.7, 0.6, 0.4)])
	var materials := []
	for shader in [baseline, candidate]:
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("soil", texture)
		materials.append(material)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.18, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	root.add_child(environment)
	var patch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	patch.mesh = plane
	root.add_child(patch)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var views := []
	var passed := true
	for location in [Vector3.ZERO, Vector3(31.37, 0, -48.91), Vector3(-83.1, 0, 121.7)]:
		patch.position = location
		for eye in [Vector3(0, 6, 0.1), Vector3(2, 2, 5), Vector3(0, 0.7, 5), Vector3(3, 8, 12)]:
			camera.position = location + eye
			camera.look_at(location)
			var images := []
			for material in materials:
				patch.material_override = material
				await process_frame
				RenderingServer.force_draw(false)
				images.append(root.get_texture().get_image())
			var identical: bool = images[0].get_data() == images[1].get_data()
			passed = passed and identical
			if not identical or views.is_empty():
				for index in range(2):
					images[index].save_png(output.path_join("view-%d-%d.png" % [views.size(), index]))
			views.append({"location": str(location), "eye": str(eye), "pixel_identical": identical})
	var report := {"passed": passed, "views": views, "scope": "OpenGL visual equivalence only; no Android performance claim"}
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TREE_LITTER_CORNER_REVIEW ", JSON.stringify(report))
	quit(0 if passed else 1)
