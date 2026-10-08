extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func signatures(mesh: Mesh) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			indices.append(i)
	var result := {}
	for i in range(0, indices.size(), 3):
		var triangle := []
		for j in range(3):
			var index := indices[i + j]
			triangle.append([arrays[Mesh.ARRAY_VERTEX][index],
				arrays[Mesh.ARRAY_NORMAL][index], arrays[Mesh.ARRAY_TEX_UV][index] if arrays[Mesh.ARRAY_TEX_UV] != null else null,
				arrays[Mesh.ARRAY_COLOR][index] if arrays[Mesh.ARRAY_COLOR] != null else null])
		result[triangle] = result.get(triangle, 0) + 1
	return result

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	root.size = Vector2i(1280, 800)
	var groups := []
	var report := []
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.38, 0.24)
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var start := source.find("\tvar seam_finish := StandardMaterial3D.new()")
	var end := source.find("\t\tvar pipe := MeshInstance3D.new()", start)
	assert(start >= 0 and end > start)
	var body := source.substr(start, end - start)
	for enabled in [false, true]:
		var script := GDScript.new()
		script.source_code = "extends RefCounted\nstatic func build(world):\n\tvar center := Vector3(15.5,0,29.5)\n" + body.replace('OS.has_feature("android")', str(enabled))
		assert(script.reload() == OK)
		var group := Node3D.new()
		root.add_child(group)
		script.build(group)
		groups.append(group)
	assert(groups[0].get_child_count() == 3)
	for i in range(3):
		var before: MeshInstance3D = groups[0].get_child(i)
		var after: MeshInstance3D = groups[1].get_child(i)
		assert(signatures(before.mesh) == signatures(after.mesh), "Oriented triangle attributes changed")
		var old_count: int = before.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		var new_count: int = after.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert(new_count < old_count)
		report.append({"name": str(before.name), "before_vertices": old_count,
			"after_vertices": new_count, "triangles": old_count / 3})
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -142, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for pose in [
		{"name": "road", "eye": Vector3(17,3,39), "target": Vector3(15.5,3,29.5)},
		{"name": "bank", "eye": Vector3(21,3,29), "target": Vector3(15.5,2,29.5)},
		{"name": "crossing", "eye": Vector3(20,10,36), "target": Vector3(15.5,3,29.5)}]:
		camera.position = pose.eye
		camera.look_at(pose.target)
		for variant in range(2):
			groups[0].visible = variant == 0
			groups[1].visible = variant == 1
			for frame in range(4):
				await process_frame
				RenderingServer.force_draw(false)
			assert(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME) > 0, "Empty geometry capture")
			assert(root.get_texture().get_image().save_png(output.path_join(
				pose.name + ("-before.png" if variant == 0 else "-after.png"))) == OK)
	var file := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"roof_details": report,
		"triangle_attributes_preserved": true,
		"scope": "Isolated shelter seams and gutters (no physics shapes), real desktop OpenGL; not Android acceptance."}, "\t"))
	file.close()
	print("SHELTER_DETAILS_INDEXING_REVIEW_PASS ", JSON.stringify(report))
	quit()
