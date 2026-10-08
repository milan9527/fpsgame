extends SceneTree

# Isolated terrain coverage/mip comparison; no world bake or resource writes.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, code: String, time: float) -> Image:
	var shader := Shader.new()
	shader.code = code.replace("TIME", str(time))
	material.shader = shader
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func review() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("TERRAIN_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(OS.get_environment("TERRAIN_SHADER_PATH"))
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
	var patch := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 5.0
	sphere.height = 10.0
	sphere.radial_segments = 96
	sphere.rings = 48
	patch.mesh = sphere
	var material := ShaderMaterial.new()
	material.set_shader_parameter("ground_map", load("res://assets/realism/ground_albedo.jpg"))
	material.set_shader_parameter("rock_map", load("res://assets/realism/terrain_rock_albedo.jpg"))
	patch.material_override = material
	scene.add_child(patch)
	var rows: Array = []
	var failed := false
	var views: Array = []
	for offset in [Vector3.ZERO, Vector3(153, 0, -217)]:
		for distance in [12.0, 35.0, 90.0]:
			views.append({"name": "sphere", "offset": offset, "distance": distance,
				"position": offset + Vector3(0, distance * 0.65, distance), "target": offset})
	for view in [
		{"name":"spawn", "position":Vector3(17,1.65,50), "target":Vector3(-1,2.2,66)},
		{"name":"road", "position":Vector3(2,1.6,61), "target":Vector3(0,3.2,-85)},
		{"name":"yard", "position":Vector3(19,1.65,48), "target":Vector3(17,0,40)},
		{"name":"crossing", "position":Vector3(7,5,8), "target":Vector3.ZERO},
		{"name":"distant", "position":Vector3(0,80,250), "target":Vector3.ZERO}]:
		views.append(view)
	for view in views:
		patch.mesh = sphere if view.name == "sphere" else load("res://assets/android_terrain.res")
		patch.position = view.get("offset", Vector3.ZERO)
		camera.position = view.position
		camera.look_at(view.target)
		var reference: Image = await capture(material, before, 0)
		var candidate: Image = await capture(material, after, 0)
		var different := 0
		var foreground := 0
		var max_error := 0.0
		var background := reference.get_pixel(0, 0)
		for y in range(reference.get_height()):
			for x in range(reference.get_width()):
				var c := reference.get_pixel(x, y)
				var d := candidate.get_pixel(x, y)
				if c != d:
					different += 1
					max_error = max(max_error, abs(c.r-d.r), abs(c.g-d.g), abs(c.b-d.b))
				if c != background:
					foreground += 1
		if max_error > 1.01 / 255.0 or foreground < 100:
			failed = true
		var name := "case-%s" % rows.size()
		reference.save_png(output.path_join(name + "-before.png"))
		candidate.save_png(output.path_join(name + "-after.png"))
		rows.append({"view": view.name, "offset": str(patch.position), "distance": view.get("distance", 0),
			"different_pixels": different, "max_channel_error": max_error,
			"foreground_pixels": foreground})
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "cases": rows,
		"scope": "OpenGL visual equivalence only; not Android performance acceptance"}, "\t"))
	file.close()
	print("TERRAIN_COVERED_REVIEW ", "FAIL" if failed else "PASS", " cases=", rows.size())
	quit(1 if failed else 0)
