extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func face_attributes(arrays: Array) -> Array:
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(i)
	var faces: Array = []
	for i in range(0, indices.size(), 3):
		var attributes: Array = []
		for j in range(3):
			var index := indices[i + j]
			attributes.append(arrays[Mesh.ARRAY_VERTEX][index])
			attributes.append(arrays[Mesh.ARRAY_NORMAL][index])
		var key := var_to_bytes(attributes).hex_encode()
		faces.append(key)
	return faces

func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var start := source.find("\t\tvar roof_surface := SurfaceTool.new()")
	var end := source.find("\t\tvar panel := MeshInstance3D.new()", start)
	assert(start >= 0 and end > start)
	var body := source.substr(start, end - start).replace("\n\t", "\n").trim_prefix("\t")
	var code := "extends RefCounted\nstatic func banks() -> Array:\n"
	code += body + "\treturn [roof_surface.commit_to_arrays()]\n"
	var snapshots: Array = []
	var scripts: Array[GDScript] = []
	for android in [false, true]:
		var script := GDScript.new()
		script.source_code = code.replace('OS.has_feature("android")', str(android))
		assert(script.reload() == OK)
		scripts.append(script)
		snapshots.append(script.banks())
	var report: Array = []
	for side in range(1):
		var before: Array = snapshots[0][side]
		var after: Array = snapshots[1][side]
		assert(face_attributes(before) == face_attributes(after), "Position/normal or triangle submission order changed")
		assert(after[Mesh.ARRAY_VERTEX].size() < before[Mesh.ARRAY_VERTEX].size())
		report.append({
			"side": side, "vertices_before": before[Mesh.ARRAY_VERTEX].size(),
			"vertices_after": after[Mesh.ARRAY_VERTEX].size(),
			"triangles": after[Mesh.ARRAY_INDEX].size() / 3,
			"exact_face_attributes": true
		})
	print("ANDROID_PANEL_INDEX_CACHE_PASS ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
		root.size = Vector2i(480, 320)
		var scene := Node3D.new()
		root.add_child(scene)
		var instance := MeshInstance3D.new()
		scene.add_child(instance)
		var opaque := ShaderMaterial.new()
		opaque.shader = load("res://shaders/canopy_sheet.gdshader")
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.64, 0.77, 0.74, 0.30)
		glass.roughness = 0.28
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		scene.add_child(light)
		var camera := Camera3D.new()
		camera.current = true
		scene.add_child(camera)
		var output := OS.get_environment("PANEL_REVIEW_DIR")
		assert(not output.is_empty())
		for side in range(1):
			var meshes: Array[ArrayMesh] = []
			for snapshot in snapshots:
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, snapshot[side])
				meshes.append(mesh)
			var center := meshes[0].get_aabb().get_center()
			for offset in [Vector3(1, 2, 2), Vector3(1, -2, 2), Vector3(-1, 2, -2), Vector3(-1, -2, -2)]:
				instance.material_override = opaque if offset.x > 0 else glass
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
				var label := ("opaque" if offset.x > 0 else "glass") + ("-above" if offset.y > 0 else "-below")
				images[0].save_png(output.path_join(label + "-before.png"))
				images[1].save_png(output.path_join(label + "-after.png"))
				print("PANEL_GL_REVIEW ", label, " differences=", differences, " foreground=", foreground)
				assert(foreground > 100)
				assert(differences == 0)
		print("PANEL_GL_REVIEW_PASS")
	quit()
