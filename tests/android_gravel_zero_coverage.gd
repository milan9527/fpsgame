extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("GRAVEL_REVIEW_DIR")
	assert(not output.is_empty())
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var scene := Node3D.new()
	root.add_child(scene)
	var instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 24)
	instance.mesh = plane
	scene.add_child(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.01
	scene.add_child(camera)
	var materials: Array[ShaderMaterial] = []
	for path in [output.path_join("yard_gravel-before.gdshader"), "res://shaders/yard_gravel.gdshader"]:
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(path)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
		material.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
		materials.append(material)
	# Include translated/rotated deposits, grazing views, inner/outer edges
	# and both traffic gaps; the same shader serves several world locations.
	for pose in range(3):
		plane.size = Vector2(12, 18) if pose == 1 else Vector2(7.6, 13.2)
		for material in materials:
			material.set_shader_parameter("half_extent", Vector2(5, 8) if pose == 1 else Vector2(2.7, 5.5))
		instance.position = Vector3(pose * 13.7, 0, -pose * 19.3)
		instance.rotation.y = pose * 0.7
		for distance in [2.0, 8.0, 24.0, 48.0]:
			camera.position = instance.position + Vector3(distance * 0.25, distance * (0.15 if pose == 2 else 0.8), distance)
			camera.look_at(instance.position + Vector3(2.7, 0, 0))
			var images: Array[Image] = []
			for material in materials:
				instance.material_override = material
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_draw(false)
				images.append(root.get_texture().get_image())
			var differences := 0
			var max_error := 0.0
			var colors := {}
			for y in range(images[0].get_height()):
				for x in range(images[0].get_width()):
					var a := images[0].get_pixel(x, y)
					var b := images[1].get_pixel(x, y)
					colors[a.to_rgba32()] = true
					if a != b:
						differences += 1
						max_error = maxf(max_error, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
			var label := "gravel-" + str(pose) + "-" + str(distance)
			images[0].save_png(output.path_join(label + "-before.png"))
			images[1].save_png(output.path_join(label + "-after.png"))
			print("GRAVEL_GL ", label, " colors=", colors.size(), " differences=", differences, " max_error=", max_error)
			if colors.size() < 16 or max_error > 1.0 / 255.0 + 0.000001:
				quit(1)
				return
	print("GRAVEL_GL_PASS")
	quit()
