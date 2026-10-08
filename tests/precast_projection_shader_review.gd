extends SceneTree

# Standalone OpenGL image comparison, without importing or baking game assets.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, shader: Shader) -> Image:
	material.shader = shader
	for frame in range(2):
		await RenderingServer.frame_post_draw
	print("PRECAST_READBACK_START ticks_ms=", Time.get_ticks_msec())
	return root.get_texture().get_image()

func review() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("CONCRETE_REVIEW_DIR")
	assert(not FileAccess.file_exists(output.path_join("comparison.json")))
	assert(not FileAccess.file_exists(output.path_join("isolated-comparison.json")))
	assert(not FileAccess.file_exists(output.path_join("partial-comparison.json")))
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(output.path_join("after.gdshader"))
	assert(not before.is_empty() and not after.is_empty())
	var before_shader := Shader.new()
	before_shader.code = before
	var after_shader := Shader.new()
	after_shader.code = after
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.14, 0.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var stone := MeshInstance3D.new()
	var material := ShaderMaterial.new()
	stone.material_override = material
	scene.add_child(stone)
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/realism/concrete_albedo.jpg"))
	assert(image != null)
	image.generate_mipmaps()
	material.set_shader_parameter("concrete_texture", ImageTexture.create_from_image(image))
	var box := BoxMesh.new()
	box.size = Vector3(3, 3, 3)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.5
	cylinder.bottom_radius = 1.5
	cylinder.height = 3.0
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	var meshes := [box, cylinder, sphere]
	var rows: Array = []
	var hashes: Dictionary = {}
	var failed := false
	# Isolate a slow driver case in a fresh process without calling a subset
	# a complete material review.
	var case_filter := OS.get_environment("CONCRETE_REVIEW_CASE")
	var selected_count := 0
	for shape in range(meshes.size()):
		stone.mesh = meshes[shape]
		var side := -1.0 if shape == 1 else 1.0
		for distance in [5.0, 12.0, 35.0]:
			var case_id := "%s-%s" % [shape, int(distance)]
			if not case_filter.is_empty() and case_filter != case_id:
				continue
			selected_count += 1
			camera.position = Vector3(side * distance * 0.4, distance * 0.35, distance)
			camera.look_at(Vector3.ZERO)
			print("PRECAST_CASE_START ", shape, " ", distance)
			var reference: Image = await capture(material, before_shader)
			print("PRECAST_REFERENCE_CAPTURED ticks_ms=", Time.get_ticks_msec())
			var candidate: Image = await capture(material, after_shader)
			print("PRECAST_CANDIDATE_CAPTURED ticks_ms=", Time.get_ticks_msec())
			hashes[reference.get_data().hex_encode().sha256_text()] = true
			var different := 0
			var foreground := 0
			var max_error := 0.0
			# Read back once; avoid millions of Image method calls dominating
			# this bounded shader review on the software OpenGL runner.
			reference.convert(Image.FORMAT_RGBA8)
			candidate.convert(Image.FORMAT_RGBA8)
			var reference_bytes := reference.get_data()
			var candidate_bytes := candidate.get_data()
			assert(reference_bytes.size() == candidate_bytes.size())
			for offset in range(0, reference_bytes.size(), 4):
				var pixel_differs := false
				var is_foreground := false
				for channel in range(4):
					var a := int(reference_bytes[offset + channel])
					var b := int(candidate_bytes[offset + channel])
					pixel_differs = pixel_differs or a != b
					is_foreground = is_foreground or a != reference_bytes[channel]
					if channel < 3:
						max_error = max(max_error, float(abs(a - b)) / 255.0)
				different += int(pixel_differs)
				foreground += int(is_foreground)
			failed = failed or max_error > 1.01 / 255.0 or foreground < 100
			var name := "case-%s" % case_id
			reference.save_png(output.path_join(name + "-before.png"))
			candidate.save_png(output.path_join(name + "-after.png"))
			rows.append({"shape": ["box", "cylinder", "sphere"][shape], "side": side, "distance": distance, "different_pixels": different,
				"max_channel_error": max_error, "foreground_pixels": foreground})
			var partial := FileAccess.open(output.path_join("partial-comparison.json"), FileAccess.WRITE)
			partial.store_string(JSON.stringify({"complete": false, "cases": rows,
				"scope": "Partial OpenGL material comparison; not acceptance"}, "\t"))
			partial.close()
			print("PRECAST_CASE_DONE ", shape, " ", distance, " ticks_ms=", Time.get_ticks_msec())
	failed = failed or selected_count == 0 or hashes.size() != rows.size()
	var complete := rows.size() == 9
	var result_name := "comparison.json" if complete else "isolated-comparison.json"
	var file := FileAccess.open(output.path_join(result_name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed and complete,
		"selected_cases_passed": not failed, "complete": complete, "cases": rows,
		"unique_reference_images": hashes.size(),
		"scope": "OpenGL visual comparison only, not Android performance acceptance"}, "\t"))
	file.close()
	print("PRECAST_PROJECTION_REVIEW ", "FAIL" if failed else ("PASS" if complete else "SUBSET_PASS"))
	quit(1 if failed else 0)
