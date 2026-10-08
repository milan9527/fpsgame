extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

# Isolated terrain coverage/mip comparison; no world bake or resource writes.
func _initialize() -> void:
	call_deferred("review")

func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()

func review() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	if OS.get_environment("TERRAIN_REVIEW_NO_MSAA") == "1":
		root.msaa_3d = Viewport.MSAA_DISABLED
	var output := OS.get_environment("TERRAIN_REVIEW_DIR")
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
	var patch: Node3D = load("res://assets/android_terrain_chunks.scn").instantiate()
	scene.add_child(patch)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/terrain_slopes_mobile.gdshader")
	material.set_shader_parameter("ground_map", load("res://assets/realism/ground_albedo.jpg"))
	material.set_shader_parameter("rock_map", load("res://assets/realism/terrain_rock_albedo.jpg"))
	material.set_shader_parameter("ground_tint", Color(0.42, 0.51, 0.37))
	var reference_material := material
	var reference_shader_path := OS.get_environment("TERRAIN_REVIEW_REFERENCE_SHADER")
	if not reference_shader_path.is_empty():
		reference_material = material.duplicate()
		var reference_shader := Shader.new()
		reference_shader.code = FileAccess.get_file_as_string(reference_shader_path)
		reference_material.shader = reference_shader
	var eligible := 0
	var triangles := 0
	for chunk in patch.get_children():
		if Visuals.terrain_chunk_is_covered(chunk):
			eligible += 1
			triangles += chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	assert(eligible == 19 and triangles == 150808)
	var probe: MeshInstance3D = patch.get_child(0)
	var original_basis := probe.basis
	probe.rotate_x(0.1)
	assert(not Visuals.terrain_chunk_is_covered(probe))
	probe.basis = original_basis
	var rows: Array = []
	var failed := false
	var views: Array = []
	for view in [
		{"name":"spawn", "position":Vector3(17,1.65,50), "target":Vector3(-1,2.2,66)},
		{"name":"road", "position":Vector3(2,1.6,61), "target":Vector3(0,3.2,-85)},
		{"name":"yard", "position":Vector3(19,1.65,48), "target":Vector3(17,0,40)},
		{"name":"crossing", "position":Vector3(7,5,8), "target":Vector3.ZERO},
		{"name":"distant", "position":Vector3(0,80,250), "target":Vector3.ZERO}]:
		views.append(view)
	for view in views:
		camera.position = view.position
		camera.look_at(view.target)
		for chunk in patch.get_children():
			chunk.material_override = reference_material
		var reference: Image = await capture()
		for chunk in patch.get_children():
			chunk.material_override = material
		Visuals.specialize_covered_terrain(patch, material)
		var specialized := 0
		for chunk in patch.get_children():
			if chunk.material_override != material:
				specialized += 1
				assert(chunk.material_override.get_shader_parameter("ground_map") == material.get_shader_parameter("ground_map"))
				assert(chunk.material_override.get_shader_parameter("ground_tint") == material.get_shader_parameter("ground_tint"))
				if OS.get_environment("TERRAIN_REVIEW_CONTROL") == "1":
					chunk.material_override = material
		assert(specialized == (eligible if root.msaa_3d == Viewport.MSAA_DISABLED else 0))
		var candidate: Image = await capture()
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
	file.store_string(JSON.stringify({"passed": not failed, "msaa_3d": root.msaa_3d, "eligible_chunks": eligible, "eligible_triangles": triangles, "cases": rows,
		"scope": "OpenGL visual equivalence only; not Android performance acceptance"}, "\t"))
	file.close()
	print("TERRAIN_COVERED_REVIEW ", "FAIL" if failed else "PASS", " cases=", rows.size())
	quit(1 if failed else 0)
