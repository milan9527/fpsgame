extends SceneTree

# Isolated GL correctness comparison. Uses the real imported blade geometry;
# freezes TIME equally in both shaders. No world bake or resource writes.
func _initialize() -> void:
	call_deferred("review")

func find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for child in node.get_children():
		var found := find_mesh(child)
		if found != null:
			return found
	return null

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
	var output := OS.get_environment("GRASS_REVIEW_DIR")
	var before := FileAccess.get_file_as_string(output.path_join("before.gdshader"))
	var after := FileAccess.get_file_as_string(OS.get_environment("GRASS_SHADER_PATH"))
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
	var patch := MultiMeshInstance3D.new()
	patch.multimesh = MultiMesh.new()
	patch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	patch.multimesh.use_custom_data = true
	patch.multimesh.use_colors = true
	patch.multimesh.instance_count = 25
	for i in range(25):
		patch.multimesh.set_instance_color(i, Color.WHITE)
		patch.multimesh.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, i * 0.63), Vector3((i % 5 - 2) * 0.3, 0, (i / 5 - 2) * 0.3)))
		patch.multimesh.set_instance_custom_data(i, Color(float(i % 7) / 7.0, 0.8 + float(i % 3) * 0.1, 0, 1))
	var material := ShaderMaterial.new()
	material.set_shader_parameter("fade_begin", 16.0)
	material.set_shader_parameter("fade_end", 24.0)
	patch.material_override = material
	scene.add_child(patch)
	var rows: Array = []
	var failed := false
	for asset in ["grass", "grass_fine", "grass_broadleaf"]:
		var model: Node = load("res://assets/realism/" + asset + ".glb").instantiate()
		var mesh := find_mesh(model)
		assert(mesh != null)
		patch.multimesh.mesh = mesh
		var roots := 0
		var vertices := 0
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			# Minimum possible colony/base/brightness/root tint per channel.
			# Blue still needs the piecewise transfer; red/green must stay
			# above its threshold for the specialized grass shader to be valid.
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for color in colors:
				if color.r * 0.74 * 0.79 * 0.8 * 0.72 <= 0.0031308 \
						or color.g * 0.83 * 0.87 * 0.8 * 0.72 <= 0.0031308:
					printerr("Grass asset violates sRGB red/green lower bound: ", asset)
					quit(1)
					return
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				vertices += 1
				if vertex.y <= 0.0:
					roots += 1
		for distance in [2.0, 20.0, 26.0]:
			camera.position = Vector3(0, 0.7, distance)
			camera.look_at(Vector3(0, 0.25, 0))
			camera.fov = 55.0 if distance == 2.0 else 6.0
			for time in [0.0, 1.73, 19.4]:
				var reference: Image = await capture(material, before, time)
				var candidate: Image = await capture(material, after, time)
				var different := 0
				var foreground := 0
				var colored_foreground := 0
				var background := reference.get_pixel(0, 0)
				for y in range(reference.get_height()):
					for x in range(reference.get_width()):
						if reference.get_pixel(x, y) != candidate.get_pixel(x, y):
							different += 1
						if reference.get_pixel(x, y) != background:
							foreground += 1
							var color := reference.get_pixel(x, y)
							if maxf(color.r, maxf(color.g, color.b)) > 0.05:
								colored_foreground += 1
				if different > 0 or (distance < 24.0 and colored_foreground < 10):
					failed = true
				var name := "%s-%s-%s" % [asset, distance, time]
				if time == 1.73:
					reference.save_png(output.path_join(name + "-before.png"))
					candidate.save_png(output.path_join(name + "-after.png"))
				rows.append({"asset": asset, "distance": distance, "time": time,
					"vertices": vertices, "zero_height_vertices": roots,
					"different_pixels": different, "foreground_pixels": foreground,
					"colored_foreground_pixels": colored_foreground})
		model.free()
	var file := FileAccess.open(output.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "cases": rows,
		"scope": "OpenGL visual equivalence only; not Android performance acceptance"}, "\t"))
	file.close()
	print("GRASS_ROOT_REVIEW ", "FAIL" if failed else "PASS", " cases=", rows.size())
	quit(1 if failed else 0)
