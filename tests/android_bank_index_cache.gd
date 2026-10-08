extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func face_attributes(arrays: Array) -> Dictionary:
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(i)
	var faces := {}
	for i in range(0, indices.size(), 3):
		var attributes: Array = []
		for j in range(3):
			var index := indices[i + j]
			attributes.append(arrays[Mesh.ARRAY_VERTEX][index])
			attributes.append(arrays[Mesh.ARRAY_NORMAL][index])
			attributes.append(arrays[Mesh.ARRAY_TEX_UV][index])
		var key := var_to_bytes(attributes).hex_encode()
		faces[key] = faces.get(key, 0) + 1
	return faces

func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var function_start := source.find("static func service_lane_verges(")
	var start := source.find("\tfor side in [-1.0, 1.0]:", function_start)
	var end := source.find("\t\tvar bank := MeshInstance3D.new()", start)
	assert(function_start >= 0 and start > function_start and end > start)
	var body := source.substr(start, end - start)
	# Execute production bank construction alone. Scenery RNG and resource
	# instantiation do not contribute to the strip's vertices.
	var scenery_start := body.find("\t\t\t# Low overlapping colonies")
	var scenery_end := body.find("\t\tstrip.generate_normals()", scenery_start)
	assert(scenery_start >= 0 and scenery_end > scenery_start)
	body = body.substr(0, scenery_start) + body.substr(scenery_end)
	var code := "extends RefCounted\nstatic func banks() -> Array:\n\tvar result: Array = []\n"
	code += body + "\t\tresult.append(strip.commit_to_arrays())\n\treturn result\n"
	var snapshots: Array = []
	var scripts: Array[GDScript] = []
	for android in [false, true]:
		var script := GDScript.new()
		script.source_code = code.replace('OS.has_feature("android")', str(android))
		assert(script.reload() == OK)
		scripts.append(script)
		snapshots.append(script.banks())
	var report: Array = []
	for side in range(2):
		var before: Array = snapshots[0][side]
		var after: Array = snapshots[1][side]
		assert(face_attributes(before) == face_attributes(after), "Position/normal/UV or oriented collision faces changed")
		assert(after[Mesh.ARRAY_VERTEX].size() < before[Mesh.ARRAY_VERTEX].size())
		report.append({
			"side": side, "vertices_before": before[Mesh.ARRAY_VERTEX].size(),
			"vertices_after": after[Mesh.ARRAY_VERTEX].size(),
			"triangles": after[Mesh.ARRAY_INDEX].size() / 3,
			"exact_face_attributes": true
		})
	print("ANDROID_BANK_INDEX_CACHE_PASS ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
		root.size = Vector2i(480, 320)
		var scene := Node3D.new()
		root.add_child(scene)
		var instance := MeshInstance3D.new()
		scene.add_child(instance)
		instance.material_override = load("res://scripts/world_visuals.gd").meadow_surface()
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		scene.add_child(light)
		var camera := Camera3D.new()
		camera.current = true
		scene.add_child(camera)
		var output := OS.get_environment("BANK_REVIEW_DIR")
		assert(not output.is_empty())
		for side in range(2):
			var meshes: Array[ArrayMesh] = []
			for snapshot in snapshots:
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, snapshot[side])
				meshes.append(mesh)
			var center := meshes[0].get_aabb().get_center()
			for offset in [Vector3(0, 12, 6), Vector3(2, 2, 3)]:
				camera.position = center + offset
				camera.look_at(center)
				var images: Array[Image] = []
				for mesh in meshes:
					instance.mesh = mesh
					await process_frame
					RenderingServer.force_draw(false)
					RenderingServer.force_draw(false)
					images.append(root.get_texture().get_image())
				var differences := 0
				var foreground := 0
				var background := images[0].get_pixel(0, 0)
				for y in range(images[0].get_height()):
					for x in range(images[0].get_width()):
						if images[0].get_pixel(x, y) != background:
							foreground += 1
						if images[0].get_pixel(x, y) != images[1].get_pixel(x, y):
							differences += 1
				var label := str(side) + ("-overview" if offset.y > 10 else "-near")
				images[0].save_png(output.path_join(label + "-before.png"))
				images[1].save_png(output.path_join(label + "-after.png"))
				print("BANK_GL_REVIEW ", label, " differences=", differences, " foreground=", foreground)
				assert(foreground > 100)
				assert(differences == 0)
		print("BANK_GL_REVIEW_PASS")
	quit()
