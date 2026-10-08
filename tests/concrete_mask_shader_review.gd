extends SceneTree

# Concrete mask comparison across slab variants and viewing distances; no resource writes.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, code: String, time: float) -> Image:
	var shader := Shader.new()
	shader.code = code.replace("TIME", str(time))
	material.shader = shader
	await process_frame
	RenderingServer.force_sync()
	RenderingServer.force_draw(true)
	await process_frame
	RenderingServer.force_sync()
	RenderingServer.force_draw(true)
	return root.get_texture().get_image()

func review() -> void:
	if not FileAccess.file_exists("res://project.godot"):
		push_error("Run this probe inside a minimal Godot project, not an empty directory.")
		quit(2)
		return
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("CONCRETE_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(OS.get_environment("CONCRETE_SHADER_PATH"))
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
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 18)
	patch.mesh = plane
	var material := ShaderMaterial.new()
	patch.material_override = material
	scene.add_child(patch)
	var rows: Array = []
	var failed := false
	var reference_hashes: Dictionary = {}
	var views: Array = []
	for variant in ["service_bay", "depot_apron", "shelter_apron", "doorway_apron", "slab_joints", "plain"]:
		for distance in [3.0, 12.0, 40.0]:
			views.append({"name": variant, "distance": distance})
	for view in views:
		for flag in ["service_bay", "depot_apron", "shelter_apron", "doorway_apron", "slab_joints"]:
			material.set_shader_parameter(flag, flag == view.name)
		camera.position = Vector3(0, view.distance * 0.65, view.distance)
		camera.look_at(Vector3.ZERO)
		var reference: Image = await capture(material, before, 0)
		var candidate: Image = await capture(material, after, 0)
		reference_hashes[reference.get_data().hex_encode().sha256_text()] = true
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
	# Detect stale framebuffer captures even when every before/after pair agrees.
	if reference_hashes.size() < views.size():
		failed = true
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "cases": rows,
		"unique_reference_images": reference_hashes.size(),
		"scope": "OpenGL visual equivalence only; not Android performance acceptance"}, "\t"))
	file.close()
	print("CONCRETE_MASK_REVIEW ", "FAIL" if failed else "PASS", " cases=", rows.size())
	quit(1 if failed else 0)
