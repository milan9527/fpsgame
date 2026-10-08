extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("LOUVER_REVIEW_DIR")
	assert(not output.is_empty())
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var scene := Node3D.new()
	root.add_child(scene)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	scene.add_child(world_environment)
	var instances: Array[MeshInstance3D] = []
	# Match the installed slats and their folded lip strips, including local Y.
	for row in range(8):
		for edge in [0, -1, 1]:
			var instance := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.018, 0.23, 2.46) if edge == 0 else Vector3(0.038, 0.014, 2.46)
			instance.mesh = box
			instance.position = Vector3(0.0, 0.55 + row * 0.265, 0.0)
			if edge != 0:
				instance.position += Basis(Vector3.FORWARD, deg_to_rad(18.0)) * Vector3(0.014, edge * 0.108, 0.0)
			instance.rotation_degrees.z = -18.0
			scene.add_child(instance)
			instances.append(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -90, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.01
	scene.add_child(camera)
	for name in ["depot_louver"]:
		var materials: Array[ShaderMaterial] = []
		for path in [output.path_join(name + "-before.gdshader"), "res://shaders/" + name + ".gdshader"]:
			var shader := Shader.new()
			shader.code = FileAccess.get_file_as_string(path)
			var material := ShaderMaterial.new()
			material.shader = shader
			materials.append(material)
		# Exercise damp lower slats, the height transition, and dry upper slats.
		for view in [Vector2(0.5, 0.55), Vector2(0.5, 1.25), Vector2(0.5, 2.4), Vector2(2, 1.4), Vector2(4, 1.4), Vector2(8, 1.4)]:
			camera.position = Vector3(view.x, view.y, view.x * 0.15)
			camera.look_at(Vector3(0.0, view.y, 0.0))
			var images: Array[Image] = []
			for material in materials:
				for instance in instances:
					instance.material_override = material
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_draw(false)
				images.append(root.get_texture().get_image())
			var differences := 0
			var max_error := 0.0
			assert(images[0].get_size() == images[1].get_size())
			var colors := {}
			for y in range(images[0].get_height()):
				for x in range(images[0].get_width()):
					var a := images[0].get_pixel(x, y)
					var b := images[1].get_pixel(x, y)
					colors[a.to_rgba32()] = true
					if a != b:
						differences += 1
						max_error = maxf(max_error, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
			var label: String = name + "-" + str(view.x) + "-height-" + str(view.y)
			images[0].save_png(output.path_join(label + "-before.png"))
			images[1].save_png(output.path_join(label + "-after.png"))
			print("LOUVER_GL ", label, " size=", images[0].get_size(), " colors=", colors.size(), " differences=", differences, " max_error=", max_error)
			if colors.size() < 16 or max_error > 1.0 / 255.0 + 0.000001:
				quit(1)
				return
	print("LOUVER_GL_PASS")
	quit()
