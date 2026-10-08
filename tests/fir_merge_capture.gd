extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(960, 720)
	RenderingServer.render_loop_enabled = false
	var world := Node3D.new()
	root.add_child(world)
	var tree: Node
	if OS.get_environment("FIR_MODEL").begins_with("res://"):
		var packed := load(OS.get_environment("FIR_MODEL")) as PackedScene
		assert(packed != null)
		tree = packed.instantiate()
	else:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(OS.get_environment("FIR_MODEL"), state) == OK)
		tree = document.generate_scene(state)
	world.add_child(tree)
	var surfaces := 0
	var triangles := 0
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		surfaces += node.mesh.get_surface_count()
		for i in range(node.mesh.get_surface_count()):
			var material := node.mesh.surface_get_material(i) as StandardMaterial3D
			if material:
				print("FIR_MATERIAL ", material.resource_name, " albedo=", material.albedo_color,
					" vertex=", material.vertex_color_use_as_albedo, " srgb=", material.vertex_color_is_srgb)
				if material.vertex_color_use_as_albedo and OS.has_environment("FIR_VERTEX_SRGB"):
					material.vertex_color_is_srgb = OS.get_environment("FIR_VERTEX_SRGB") == "1"
			var arrays: Array = node.mesh.surface_get_arrays(i)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.36, 0.40)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 0.94)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45, -35, 0)
	var camera := Camera3D.new()
	camera.fov = 35
	world.add_child(camera)
	camera.position = Vector3(11, 6, 12)
	camera.look_at(Vector3(0, 4.2, 0))
	if OS.get_environment("PALETTE_REVIEW_SHRUB") == "1":
		camera.position = Vector3(2, 1.3, 2)
		camera.look_at(Vector3(0, 0.45, 0))
	camera.current = true
	for i in range(8):
		await process_frame
		RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(OS.get_environment("FIR_CAPTURE")) == OK)
	print("FIR_CAPTURE surfaces=", surfaces, " triangles=", triangles)
	quit()
