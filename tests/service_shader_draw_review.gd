extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	RenderingServer.render_loop_enabled = false
	if OS.get_environment("SERVICE_MSAA") == "4":
		root.msaa_3d = Viewport.MSAA_4X
	var scene := Node3D.new()
	root.add_child(scene)
	var road := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 36)
	road.mesh = plane
	var material = load("res://scripts/world_visuals.gd").service_ground_material()
	var access_review := OS.get_environment("SERVICE_MATERIAL") == "access"
	if access_review:
		material.shader = load("res://shaders/service_access.gdshader")
		material.set_shader_parameter("aggregate", load("res://assets/realism/terrain_rock_albedo.jpg"))
	var shader_path := OS.get_environment("SERVICE_SHADER_PATH")
	if not shader_path.is_empty():
		material.shader = Shader.new()
		material.shader.code = FileAccess.get_file_as_string(shader_path)
	if OS.get_environment("SERVICE_PHYSICAL_SHOULDER") == "1":
		material.set_shader_parameter("physical_shoulder", true)
	road.material_override = material
	scene.add_child(road)
	road.position = Vector3(16, 0, 38)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -142, 0)
	scene.add_child(sun)
	# Match the local-light shader variants used around the service shelter.
	# This remains a diagnostic plane, not a visual acceptance capture.
	var local_light_count := int(OS.get_environment("SERVICE_LOCAL_LIGHTS"))
	for i in range(local_light_count):
		var lamp := SpotLight3D.new()
		scene.add_child(lamp)
		lamp.position = Vector3(16 + (i % 3 - 1) * 2, 3, 33 + (i / 3) * 2)
		lamp.rotation_degrees.x = -90
		lamp.spot_range = 12
		lamp.light_energy = 2
	print("SERVICE_SHADER_LOCAL_LIGHTS count=", local_light_count)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(16, 1.6, 39)
	camera.look_at(Vector3(16, 0, 30))
	if access_review:
		camera.position = Vector3(16, 2.6, 43)
		camera.look_at(Vector3(15.5, 0, 38))
	camera.current = true
	await process_frame
	print("SERVICE_SHADER_DRAW_BEGIN ms=", Time.get_ticks_msec())
	RenderingServer.force_draw(false)
	print("SERVICE_SHADER_DRAW_END ms=", Time.get_ticks_msec())
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var error := root.get_texture().get_image().save_png(output.path_join("service-shader.png"))
	if error != OK:
		quit(1)
		return
	print("SERVICE_SHADER_DRAW_PASS diagnostic isolated plane; not environment acceptance")
	quit()
