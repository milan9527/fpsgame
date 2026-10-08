extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	RenderingServer.render_loop_enabled = false
	var scene := Node3D.new()
	root.add_child(scene)
	var road := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 225)
	road.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/road_surface.gdshader")
	var shader_path := OS.get_environment("ROAD_SHADER_PATH")
	if not shader_path.is_empty():
		material.shader = Shader.new()
		material.shader.code = FileAccess.get_file_as_string(shader_path)
	if OS.get_environment("ROAD_SHADER_NO_BUMP") == "1":
		material.shader = material.shader.duplicate()
		var bump_line := "NORMAL=normalize(NORMAL-gradient+NORMAL*dot(NORMAL,gradient));"
		if not material.shader.code.contains(bump_line):
			bump_line = "NORMAL=normalize(abs(determinant)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2));"
		assert(material.shader.code.contains(bump_line))
		material.shader.code = material.shader.code.replace(bump_line, "// Isolated diagnostic: aggregate relief disabled.")
	material.set_shader_parameter("aggregate", load("res://assets/realism/terrain_rock_albedo.jpg"))
	material.set_shader_parameter("pavement", load("res://assets/realism/asphalt_surface.png"))
	var visuals = load("res://scripts/world_visuals.gd")
	var reference_cover: Texture2D
	if OS.get_environment("ROAD_REVIEW_FLOAT_COVER") == "1":
		reference_cover = visuals.meadow_surface().get_shader_parameter("colony_map")
	visuals.bake_android_ground = OS.get_environment("ROAD_REVIEW_MOBILE") == "1"
	var meadow: ShaderMaterial = visuals.meadow_surface()
	if reference_cover != null:
		meadow.set_shader_parameter("colony_map", reference_cover)
	for parameter in ["soil", "gravel", "soil_normal", "gravel_normal", "colony_map", "noise_lattice", "cached_noise"]:
		material.set_shader_parameter(parameter, meadow.get_shader_parameter(parameter))
	road.material_override = material
	scene.add_child(road)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -142, 0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(2, 1.6, 61)
	camera.look_at(Vector3(0, 3.2, -85))
	# Exercise the blend boundary, intersection, and road end as well as asphalt.
	match OS.get_environment("ROAD_REVIEW_VIEW"):
		"shoulder":
			camera.position = Vector3(6, 2.5, 30)
			camera.look_at(Vector3(3.5, 0, 15))
		"crossing":
			camera.position = Vector3(7, 5, 8)
			camera.look_at(Vector3.ZERO)
		"end":
			camera.position = Vector3(4, 3, 100)
			camera.look_at(Vector3(2, 0, 111))
	camera.current = true
	await process_frame
	print("ROAD_SHADER_DRAW_BEGIN ms=", Time.get_ticks_msec())
	RenderingServer.force_draw(false)
	print("ROAD_SHADER_DRAW_END ms=", Time.get_ticks_msec())
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var error := root.get_texture().get_image().save_png(output.path_join("road-shader.png"))
	if error != OK:
		quit(1)
		return
	print("ROAD_SHADER_DRAW_PASS diagnostic isolated plane; not environment acceptance")
	quit()
