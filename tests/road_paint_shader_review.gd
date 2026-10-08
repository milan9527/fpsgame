extends SceneTree

# Isolated OpenGL comparison; synthetic textures exercise all material branches
# without loading the world, importing assets, or enabling resource baking.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, code: String) -> Image:
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func review() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("ROAD_PAINT_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string("res://shaders/road_surface_mobile.gdshader")
	assert(not before.is_empty() and not after.is_empty())
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var surface := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(230, 230)
	surface.mesh = plane
	var material := ShaderMaterial.new()
	for name in ["pavement", "soil", "gravel", "soil_normal", "gravel_normal", "colony_map"]:
		var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in range(64):
			for x in range(64):
				var value := float((x * 7 + y * 11) % 64) / 63.0
				var color := Color(0.2 + value * 0.6, 0.3 + value * 0.4, 0.2 + value * 0.3)
				if name.ends_with("_normal"):
					color = Color(0.4 + value * 0.2, 0.6 - value * 0.2, 1.0)
				elif name == "colony_map":
					color = Color(float(x) / 63.0, float(y) / 63.0, 0)
				image.set_pixel(x, y, color)
		image.generate_mipmaps()
		material.set_shader_parameter(name, ImageTexture.create_from_image(image))
	surface.material_override = material
	scene.add_child(surface)
	var rows: Array = []
	var failed := false
	var views := [
		[Vector3(2, 1.7, 14), Vector3(3.15, 0, 25)],
		[Vector3(10, 9, 12), Vector3.ZERO],
		[Vector3(4, 2, 95), Vector3(3.15, 0, 112)],
		[Vector3(12, 30, 60), Vector3(0, 0, 95)],
	]
	for index in range(views.size()):
		camera.position = views[index][0]
		camera.look_at(views[index][1])
		var old_image: Image = await capture(material, before)
		var new_image: Image = await capture(material, after)
		old_image.save_png(output.path_join("%d-before.png" % index))
		new_image.save_png(output.path_join("%d-after.png" % index))
		var old_bytes := old_image.get_data()
		var new_bytes := new_image.get_data()
		var changed := 0
		var max_delta := 0
		for byte in range(old_bytes.size()):
			var delta := absi(int(old_bytes[byte]) - int(new_bytes[byte]))
			if delta > 0:
				changed += 1
				max_delta = maxi(max_delta, delta)
		rows.append({"view": index, "changed_bytes": changed, "max_byte_delta": max_delta})
		failed = failed or max_delta > 1
	var report := {"renderer": RenderingServer.get_video_adapter_name(),
		"synthetic_textures": true, "views": rows, "passed": not failed,
		"limitation": "OpenGL image equivalence only; no Android performance or acceptance claim."}
	FileAccess.open(output.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("ROAD_PAINT_REVIEW ", JSON.stringify(report))
	quit(1 if failed else 0)
