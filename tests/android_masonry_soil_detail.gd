extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("MASONRY_REVIEW_DIR")
	assert(not output.is_empty())
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var scene := Node3D.new()
	root.add_child(scene)
	var lighting := WorldEnvironment.new()
	lighting.environment = Environment.new()
	lighting.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.environment.ambient_light_color = Color.WHITE
	lighting.environment.ambient_light_energy = 0.6
	scene.add_child(lighting)
	var shell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 3, 0.4)
	shell.mesh = box
	shell.position = Vector3(0, 1.3, 0)
	scene.add_child(shell)
	var meshes: Array[MeshInstance3D] = [shell]
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.01
	scene.add_child(camera)
	var materials: Array[ShaderMaterial] = []
	for path in [output.path_join("workshop_masonry-before.gdshader"), "res://shaders/workshop_masonry.gdshader"]:
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(path)
		var material := ShaderMaterial.new()
		material.shader = shader
		materials.append(material)
	var views := [Vector3(0, 0, 6), Vector3(0, 4, 3), Vector3(0, -1, 3),
		Vector3(6, 1, 0), Vector3(-6, 1, 0), Vector3(0, 0, -6),
		Vector3(1.6, 0, 2), Vector3(0, 12, 16)]
	# Include the production foundation/porch heights and cement that can
	# restore coating weight over otherwise completely exposed brick.
	var finishes := [
		Vector3(0.0, 0.0, 0.0), Vector3(0.24, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.4, 0.3),
		Vector3(0.91, 0.0, 0.0), Vector3(1.32, 0.0, 0.0),
		Vector3(0.91, 1.0, 0.0), Vector3(1.32, 0.4, 0.3)]
	for index in range(views.size() * finishes.size()):
		var finish := index / views.size()
		for material in materials:
			material.set_shader_parameter("exposed_brick_height", finishes[finish].x)
			material.set_shader_parameter("aged_plinth_render", finishes[finish].y)
			material.set_shader_parameter("reclaimed_variation", finishes[finish].z)
		camera.position = shell.position + views[index % views.size()]
		camera.look_at(shell.position)
		var images: Array[Image] = []
		for material in materials:
			for mesh in meshes:
				mesh.material_override = material
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
		images[0].save_png(output.path_join("view-%d-before.png" % index))
		images[1].save_png(output.path_join("view-%d-after.png" % index))
		print("MASONRY_SOIL_GL view=", index, " colors=", colors.size(), " differences=", differences, " max_error=", max_error)
		if colors.size() < 16 or differences != 0:
			quit(1)
			return
	print("MASONRY_SOIL_GL_PASS (visual equivalence only; not Android timing acceptance)")
	quit()
