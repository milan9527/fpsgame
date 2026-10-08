extends SceneTree

# Isolated service yard noise support comparison; no world bake or resource writes.
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
	var output := OS.get_environment("YARD_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(OS.get_environment("YARD_SHADER_PATH"))
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
	patch.mesh = plane
	var material := ShaderMaterial.new()
	material.set_shader_parameter("concrete", load("res://assets/realism/concrete_albedo.jpg"))
	material.set_shader_parameter("gravel", load("res://assets/realism/terrain_rock_albedo.jpg"))
	material.set_shader_parameter("soil", load("res://assets/realism/ground_albedo.jpg"))
	patch.material_override = material
	scene.add_child(patch)
	var rows: Array = []
	var failed := false
	var views: Array = []
	for parking in [true, false]:
		for center in [Vector2(25, 40), Vector2(-25, -65)]:
			for distance in [5.0, 18.0, 45.0, 65.0]:
				for height in [0.15, 0.85]:
					views.append({"parking": parking, "center": center, "distance": distance, "height": height})
	for view in views:
		var center: Vector2 = view.center
		var extent := Vector2(11.5, 12.5) if view.parking else Vector2(5, 3)
		plane.size = (extent + Vector2(2, 2)) * 2
		# Production yard vertices are in world coordinates; use mesh center_offset
		# to exercise both local yard UV and world noise with an identity model.
		plane.center_offset = Vector3(center.x, 0, center.y)
		material.set_shader_parameter("half_extent", extent)
		material.set_shader_parameter("yard_center", center)
		material.set_shader_parameter("parking", view.parking)
		var target := Vector3(center.x, 0, center.y)
		camera.position = target + Vector3(0, view.distance * view.height, view.distance)
		camera.look_at(target)
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
		rows.append({"parking": view.parking, "center": str(view.center), "height": view.height, "distance": view.get("distance", 0),
			"different_pixels": different, "max_channel_error": max_error,
			"foreground_pixels": foreground})
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "cases": rows,
		"scope": "OpenGL visual equivalence only; not Android performance acceptance"}, "\t"))
	file.close()
	print("SERVICE_YARD_REVIEW ", "FAIL" if failed else "PASS", " cases=", rows.size())
	quit(1 if failed else 0)
