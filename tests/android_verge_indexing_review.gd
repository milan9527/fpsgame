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
				arrays[Mesh.ARRAY_NORMAL][index], arrays[Mesh.ARRAY_TEX_UV][index]])
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
	for enabled in [false, true]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://scripts/world_visuals.gd").replace('OS.has_feature("android")', str(enabled)).replace('\tverge_cover(world)\n', '')
		assert(script.reload() == OK)
		var group := Node3D.new()
		root.add_child(group)
		script.verge_relief(group)
		for bank in group.get_children():
			bank.material_override = material
		groups.append(group)
	for i in range(5):
		var before: MeshInstance3D = groups[0].get_child(i)
		var after: MeshInstance3D = groups[1].get_child(i)
		assert(signatures(before.mesh) == signatures(after.mesh), "Oriented triangle attributes changed")
		var before_faces: PackedVector3Array = before.get_child(0).get_child(0).shape.get_faces()
		var after_faces: PackedVector3Array = after.get_child(0).get_child(0).shape.get_faces()
		var faces := {}
		for j in range(0, before_faces.size(), 3):
			var key := [before_faces[j], before_faces[j + 1], before_faces[j + 2]]
			faces[key] = faces.get(key, 0) + 1
		for j in range(0, after_faces.size(), 3):
			var key := [after_faces[j], after_faces[j + 1], after_faces[j + 2]]
			assert(faces.has(key) and faces[key] > 0)
			faces[key] -= 1
		assert(before_faces.size() == after_faces.size())
		for count in faces.values():
			assert(count == 0)
		var old_count: int = before.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		var new_count: int = after.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert(new_count < old_count)
		report.append({"name": str(before.name), "before_vertices": old_count,
			"after_vertices": new_count, "triangles": before_faces.size() / 3})
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -142, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for pose in [
		{"name": "south", "eye": Vector3(-20,10,67), "target": Vector3(-26,0,56)},
		{"name": "north", "eye": Vector3(21,9,-25), "target": Vector3(12,0,-38)},
		{"name": "west", "eye": Vector3(-19,8,-4), "target": Vector3(-25,0,-13)},
		{"name": "repair", "eye": Vector3(-10,8,54), "target": Vector3(-18,0,45)},
		{"name": "central", "eye": Vector3(-4,9,33), "target": Vector3(-14,0,22)}]:
		camera.position = pose.eye
		camera.look_at(pose.target)
		for variant in range(2):
			groups[0].visible = variant == 0
			groups[1].visible = variant == 1
			await process_frame
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(output.path_join(
				pose.name + ("-before.png" if variant == 0 else "-after.png"))) == OK)
	var file := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"banks": report,
		"triangle_attributes_and_collision_preserved": true,
		"scope": "Isolated grass banks (cover excluded from both comparison groups), neutral material, real desktop OpenGL; not Android acceptance."}, "\t"))
	file.close()
	print("VERGE_INDEXING_REVIEW_PASS ", JSON.stringify(report))
	quit()
