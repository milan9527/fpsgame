extends SceneTree

# Isolated actual OpenGL mesh comparison, not Android performance acceptance.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	var source := FileAccess.get_file_as_string(OS.get_environment("WORLD_VISUALS_SOURCE"))
	var lane := OS.get_environment("GRAVEL_REVIEW_KIND") == "lane"
	var apron := OS.get_environment("GRAVEL_REVIEW_KIND") == "apron"
	var function_name := "repair_service_access" if apron else ("service_lane_verges" if lane else "service_yard_recovery")
	var mesh_name := "pebble_mesh" if apron else ("stone_mesh" if lane else "mesh")
	var batch_name := "pebbles" if apron else ("stones" if lane else "batch")
	var function := source.split("static func %s(world) -> void:" % function_name)[1].split("\nstatic func ")[0]
	var declaration := "\tvar %s := SphereMesh.new()" % mesh_name
	var mesh_code := declaration + function.split(declaration)[1].split("\tvar %s :=" % batch_name)[0]
	var meshes := []
	for android in [false, true]:
		var script := GDScript.new()
		script.source_code = "extends RefCounted\nstatic func build():\n" + mesh_code.replace('OS.has_feature("android")', str(android)) + "\treturn %s\n" % mesh_name
		assert(script.reload() == OK)
		meshes.append(script.build())
	var triangles := []
	for mesh in meshes:
		triangles.append(mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3)
	assert(triangles == ([48, 24] if apron else ([30, 20] if lane else [56, 28])), str(triangles))
	# PrimitiveMesh reports its nominal radius, so compare actual vertices.
	var bounds := []
	for mesh in meshes:
		var vertices: PackedVector3Array = mesh.get_mesh_arrays()[Mesh.ARRAY_VERTEX]
		var box := AABB(vertices[0], Vector3.ZERO)
		for vertex in vertices:
			box = box.expand(vertex)
		bounds.append(box)
	assert(bounds[0].is_equal_approx(bounds[1]), str(bounds))
	root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(sun)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	floor_node.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("6c6554")
	floor_node.material_override = floor_mat
	root.add_child(floor_node)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = meshes[0]
	batch.instance_count = 820 if apron else (1600 if lane else 1706)
	var rng := RandomNumberGenerator.new()
	rng.seed = 213045
	for i in range(batch.instance_count):
		var size := rng.randf_range(0.016, 0.052) if lane else rng.randf_range(0.02, 0.065)
		var tilt := 1.0 if lane else 0.3
		var basis := Basis.from_euler(Vector3(rng.randf()*tilt, rng.randf()*TAU, rng.randf()*tilt))
		basis = basis.scaled(Vector3(size, size*0.42, size*0.72) if lane else Vector3(size, size*0.32, size*rng.randf_range(0.6, 1.25)))
		if apron:
			size = rng.randf_range(0.012, 0.043)
			basis = Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3(size, size*0.38, size*0.72))
		batch.set_instance_transform(i, Transform3D(basis, Vector3(rng.randf_range(-3, 3), 0.045, rng.randf_range(-3, 3))))
		batch.set_instance_color(i, Color("585750").lerp(Color("aaa393"), rng.randf()))
	var original_buffer := batch.buffer.duplicate()
	var stones := MultiMeshInstance3D.new()
	stones.multimesh = batch
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.albedo_color = Color("6c6554")
	surface.roughness = 0.97
	stones.material_override = surface
	root.add_child(stones)
	var results := []
	for view in [
		{"name":"standing", "position":Vector3(0, 1.6, 2), "target":Vector3.ZERO},
		{"name":"close", "position":Vector3(0, 0.3, 0.4), "target":Vector3.ZERO}
	]:
		camera.position = view.position
		camera.look_at(view.target)
		for mode in range(2):
			batch.mesh = meshes[mode]
			assert(batch.buffer == original_buffer, "Mesh replacement must preserve all transforms/colors")
			for frame in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var label: String = view.name + ("-android" if mode else "-before")
			assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
			results.append({"view":label,
				"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
				"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
	var report := {"scope":"Isolated desktop OpenGL; representative placement fixture, not full world or phone acceptance",
		"source_function":function_name, "vertex_bounds_preserved":true,
		"triangles_per_stone":triangles, "instances":batch.instance_count,
		"transforms_colors_preserved":batch.buffer == original_buffer, "views":results}
	FileAccess.open(output.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("YARD_GRAVEL_REVIEW ", JSON.stringify(report))
	quit()
