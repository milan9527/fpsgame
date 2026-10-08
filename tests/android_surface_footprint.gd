extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("FOOTPRINT_REVIEW_DIR")
	assert(not output.is_empty())
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var scene := Node3D.new()
	root.add_child(scene)
	var instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	instance.mesh = plane
	scene.add_child(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.01
	scene.add_child(camera)
	for name in ["drainage_stone", "warehouse_concrete"]:
		var materials: Array[ShaderMaterial] = []
		for path in [output.path_join(name + "-before.gdshader"), "res://shaders/" + name + ".gdshader"]:
			var shader := Shader.new()
			shader.code = FileAccess.get_file_as_string(path)
			var material := ShaderMaterial.new()
			material.shader = shader
			if name == "drainage_stone":
				material.set_shader_parameter("rock_texture", load("res://assets/realism/terrain_rock_albedo.jpg"))
			materials.append(material)
		# Heights span fully visible, transitioning, and fully filtered detail.
		for distance in [0.25, 1.0, 4.0, 16.0, 48.0]:
			camera.position = Vector3(0.1, distance, distance)
			camera.look_at(Vector3.ZERO)
			var images: Array[Image] = []
			for material in materials:
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
			var label: String = name + "-" + str(distance)
			images[0].save_png(output.path_join(label + "-before.png"))
			images[1].save_png(output.path_join(label + "-after.png"))
			print("FOOTPRINT_GL ", label, " size=", images[0].get_size(), " colors=", colors.size(), " differences=", differences, " max_error=", max_error)
			if colors.size() < 16 or max_error > 1.0 / 255.0 + 0.000001:
				quit(1)
				return
	print("FOOTPRINT_GL_PASS")
	quit()
