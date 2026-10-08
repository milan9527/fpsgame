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

func face_signatures(faces: PackedVector3Array) -> Dictionary:
	var result := {}
	for i in range(0, faces.size(), 3):
		var face := [faces[i], faces[i + 1], faces[i + 2]]
		result[face] = result.get(face, 0) + 1
	return result

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	root.size = Vector2i(1280, 800)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	root.add_child(environment)
	var groups := []
	var report := []
	for enabled in [false, true]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://scripts/world_visuals.gd").replace('OS.has_feature("android")', str(enabled))
		assert(script.reload() == OK)
		var group := Node3D.new()
		root.add_child(group)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/precast_concrete.gdshader")
		material.set_shader_parameter("concrete_texture", load("res://assets/realism/concrete_albedo.jpg"))
		var mesh: Mesh = script.drainage_pipe_mesh()
		for offset in [Vector3(-0.9,0.9,0), Vector3(0.9,0.9,0.15), Vector3(0,2.43,0.05)]:
			var pipe := MeshInstance3D.new()
			pipe.mesh = mesh
			pipe.material_override = material
			pipe.position = offset
			group.add_child(pipe)
			pipe.create_trimesh_collision()
		groups.append(group)
	for i in range(3):
		var before: Mesh = groups[0].get_child(i).mesh
		var after: Mesh = groups[1].get_child(i).mesh
		assert(signatures(before) == signatures(after), "Oriented triangle attributes changed")
		var before_shape: ConcavePolygonShape3D = groups[0].get_child(i).get_child(0).get_child(0).shape
		var after_shape: ConcavePolygonShape3D = groups[1].get_child(i).get_child(0).get_child(0).shape
		assert(face_signatures(before_shape.get_faces()) == face_signatures(after_shape.get_faces()), "Collision faces changed")
		var old_count: int = before.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		var new_count: int = after.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert(new_count < old_count)
		report.append({"part": i, "before_vertices": old_count,
			"after_vertices": new_count, "triangles": old_count / 3})
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, -142, 0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for pose in [
		{"name": "approach", "eye": Vector3(6,1.6,12), "target": Vector3(0,1.5,0)},
		{"name": "grazing", "eye": Vector3(4,5,5), "target": Vector3(0,1.5,0)},
		{"name": "inside", "eye": Vector3(-0.9,0.9,-3), "target": Vector3(-0.9,0.9,0)},
		{"name": "far", "eye": Vector3(12,1.6,30), "target": Vector3(0,1.5,0)}]:
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
	file.store_string(JSON.stringify({"pipes": report,
		"oriented_triangle_attributes_preserved": true, "collision_faces_preserved": true,
		"scope": "Isolated drainage pipe stack, original shaders, desktop OpenGL Android branch simulation; not Android acceptance."}, "\t"))
	file.close()
	print("PIPE_INDEXING_REVIEW_PASS ", JSON.stringify(report))
	quit()
