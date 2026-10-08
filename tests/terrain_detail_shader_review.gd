extends SceneTree

# Standalone OpenGL image comparison, without importing or baking game assets.
func _initialize() -> void:
	call_deferred("review")

func capture(material: ShaderMaterial, code: String) -> Image:
	var shader := Shader.new()
	shader.code = code
	material.shader = shader
	for frame in range(2):
		await process_frame
		RenderingServer.force_sync()
		RenderingServer.force_draw(true)
	return root.get_texture().get_image()

func review() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(640, 480)
	var output := OS.get_environment("TERRAIN_REVIEW_DIR")
	assert(not FileAccess.file_exists(output.path_join("comparison.json")))
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(output.path_join("after.gdshader"))
	assert(not before.is_empty() and not after.is_empty())
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
	var sphere := SphereMesh.new()
	sphere.radius = 20.0
	sphere.height = 40.0
	stone.mesh = sphere
	stone.scale = Vector3(1.3, 0.6, 0.8)
	var material := ShaderMaterial.new()
	stone.material_override = material
	scene.add_child(stone)
	for pair in [["ground_map", "terrain_rock_albedo.jpg"], ["rock_map", "terrain_rock_albedo.jpg"], ["rock_normal", "terrain_rock_normal.jpg"], ["rock_roughness", "terrain_rock_roughness.jpg"]]:
		var image := Image.load_from_file(OS.get_environment("TERRAIN_TEXTURE_DIR").path_join(pair[1]))
		assert(image != null)
		image.generate_mipmaps()
		material.set_shader_parameter(pair[0], ImageTexture.create_from_image(image))
	var rows: Array = []
	var hashes: Dictionary = {}
	var failed := false
	var total_covered := 0
	var total_exposed := 0
	var mask_code := after.substr(0, after.rfind("}")) + """
	ALBEDO = vec3(0.0);
	EMISSION = exposed > 0.0 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	SPECULAR = 0.0;
}
"""
	for fixture in ["sphere", "flat", "slope25", "slope50"]:
		stone.position = Vector3.ZERO
		stone.rotation = Vector3.ZERO
		stone.scale = Vector3.ONE
		if fixture == "sphere":
			stone.mesh = sphere
			stone.scale = Vector3(1.3, 0.6, 0.8)
		else:
			var plane := PlaneMesh.new()
			plane.size = Vector2(60, 60)
			stone.mesh = plane
			stone.position.y = 24.0
			if fixture == "slope25":
				stone.rotation_degrees.x = 25.0
			elif fixture == "slope50":
				stone.rotation_degrees.x = 50.0
		for side in [-1.0, 1.0]:
			for distance in [40.0, 75.0, 150.0]:
				camera.position = stone.position + Vector3(side * distance * 0.4, distance * 0.65, distance)
				camera.look_at(stone.position)
				var reference: Image = await capture(material, before)
				var candidate: Image = await capture(material, after)
				var mask: Image = await capture(material, mask_code)
				hashes[reference.get_data().hex_encode().sha256_text()] = true
				var different := 0
				var foreground := 0
				var covered_pixels := 0
				var exposed_pixels := 0
				var max_error := 0.0
				for y in range(reference.get_height()):
					for x in range(reference.get_width()):
						var a := reference.get_pixel(x, y)
						var b := candidate.get_pixel(x, y)
						var m := mask.get_pixel(x, y)
						if m.g > 0.8 and m.r < 0.1:
							covered_pixels += 1
						elif m.r > 0.8 and m.g < 0.1:
							exposed_pixels += 1
						if a != b:
							different += 1
							max_error = max(max_error, abs(a.r-b.r), abs(a.g-b.g), abs(a.b-b.b))
						if a != reference.get_pixel(0, 0):
							foreground += 1
				failed = failed or max_error > 1.01 / 255.0 or foreground < 100
				var name := "case-%s" % rows.size()
				reference.save_png(output.path_join(name + "-before.png"))
				candidate.save_png(output.path_join(name + "-after.png"))
				mask.save_png(output.path_join(name + "-coverage.png"))
				total_covered += covered_pixels
				total_exposed += exposed_pixels
				failed = failed or (fixture == "flat" and covered_pixels < 100)
				rows.append({"fixture": fixture, "side": side, "distance": distance, "different_pixels": different,
					"covered_pixels": covered_pixels, "exposed_pixels": exposed_pixels,
					"max_channel_error": max_error, "foreground_pixels": foreground})
	failed = failed or hashes.size() != rows.size()
	failed = failed or total_covered < 100 or total_exposed < 100
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "cases": rows,
		"unique_reference_images": hashes.size(),
		"scope": "OpenGL visual comparison only, not Android performance acceptance"}, "\t"))
	file.close()
	print("TERRAIN_DETAIL_REVIEW ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
