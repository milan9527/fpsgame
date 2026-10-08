extends SceneTree

# Run in a minimal OpenGL project. Compare actual depth-texture rendering.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, code: String) -> Image:
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	for frame in range(3):
		await process_frame
		RenderingServer.force_sync()
		RenderingServer.force_draw(true)
	return root.get_texture().get_image()

func review() -> void:
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var output := OS.get_environment("SMOKE_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(OS.get_environment("SMOKE_SHADER_PATH"))
	assert(not before.is_empty() and not after.is_empty())
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.1, 0.2, 0.3)
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(30, 30, 0.2)
	wall.mesh = box
	var opaque := StandardMaterial3D.new()
	opaque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	opaque.albedo_color = Color(0.5, 0.2, 0.1)
	wall.material_override = opaque
	scene.add_child(wall)
	var cloud := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 32
	sphere.rings = 16
	cloud.mesh = sphere
	cloud.scale = Vector3.ONE * 3
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.set_shader_parameter("radius", 3.0)
	material.set_shader_parameter("density", 0.7)
	material.set_shader_parameter("age", 4.0)
	cloud.material_override = material
	scene.add_child(cloud)
	var rows: Array = []
	var hashes: Dictionary = {}
	var passed := true
	var origin := Vector3(173, 12, -219) if OS.get_environment("SMOKE_TRANSLATED") == "1" else Vector3.ZERO
	cloud.position = origin
	for view in [
		{"name": "clear", "camera": Vector3(0, 0, 8), "wall": Vector3(0, 0, -5)},
		{"name": "occluded", "camera": Vector3(0, 0, 8), "wall": Vector3(0, 0, 4)},
		{"name": "partial", "camera": Vector3(0, 0, 8), "wall": Vector3(15, 0, 4)},
		{"name": "intersecting", "camera": Vector3(0, 0, 8), "wall": Vector3(0, 0, 0)},
		{"name": "inside", "camera": Vector3(0, 0, 1), "wall": Vector3(0, 0, -1)},
		{"name": "core_clipped", "camera": Vector3(0, 0, 0.5), "wall": Vector3(0, 0, -0.5)},
		{"name": "core_boundary", "camera": Vector3(0, 0, 1.94), "wall": Vector3(0, 0, -1.94)},
		{"name": "edge", "camera": Vector3(3, 0, 8), "wall": Vector3(15, 0, 4)}
	]:
		camera.position = origin + view.camera
		camera.look_at(origin)
		wall.position = origin + view.wall
		var reference := await capture(material, before)
		var candidate := await capture(material, after)
		cloud.visible = false
		var without_smoke := await capture(material, after)
		cloud.visible = true
		hashes[reference.get_data().hex_encode().sha256_text()] = true
		var different := 0
		var smoke_pixels := 0
		var max_error := 0.0
		for y in range(reference.get_height()):
			for x in range(reference.get_width()):
				var a := reference.get_pixel(x, y)
				var b := candidate.get_pixel(x, y)
				if a != without_smoke.get_pixel(x, y):
					smoke_pixels += 1
				if a != b:
					different += 1
					max_error = max(max_error, abs(a.r-b.r), abs(a.g-b.g), abs(a.b-b.b))
		passed = passed and max_error <= 1.01 / 255.0
		passed = passed and (smoke_pixels == 0 if view.name == "occluded" else smoke_pixels > 0)
		reference.save_png(output.path_join(view.name + "-before.png"))
		candidate.save_png(output.path_join(view.name + "-after.png"))
		rows.append({"view": view.name, "different_pixels": different,
			"visible_smoke_pixels": smoke_pixels, "max_channel_error": max_error})
	passed = passed and hashes.size() == rows.size()
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "cases": rows,
		"unique_reference_images": hashes.size(),
		"scope": "OpenGL visual equivalence; not Android performance acceptance"}, "\t"))
	file.close()
	print("SMOKE_OCCLUSION_REVIEW ", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
