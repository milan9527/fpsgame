extends SceneTree

const Profile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 600)
	var world := Node3D.new()
	root.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(18, 0, -9))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.36, 0.40)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 0.94)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var material := ShaderMaterial.new()
	var shader_path := OS.get_environment("BATCH_REVIEW_SHADER")
	assert(shader_path in ["res://shaders/warehouse_concrete.gdshader", "res://shaders/workshop_masonry.gdshader"])
	material.shader = load(shader_path)
	# In-memory source override permits same-scene shader regression captures.
	# It deliberately retains the allowlisted resource identity for batching.
	var shader_source := OS.get_environment("BATCH_REVIEW_SHADER_SOURCE")
	if not shader_source.is_empty():
		assert(FileAccess.file_exists(shader_source))
		material.shader.code = FileAccess.get_file_as_string(shader_source)
	if shader_path.ends_with("workshop_masonry.gdshader"):
		material.set_shader_parameter("aged_plinth_render", OS.get_environment("BATCH_REVIEW_AGED_RENDER").to_float())
		material.set_shader_parameter("exposed_brick_height", OS.get_environment("BATCH_REVIEW_BRICK_HEIGHT").to_float())
	var originals: Array[MeshInstance3D] = []
	var bodies: Array[StaticBody3D] = []
	var scaled_originals: Array[MeshInstance3D] = []
	var spread_structures := OS.get_environment("BATCH_REVIEW_SPREAD_STRUCTURES") == "1"
	for i in range(8):
		var part := MeshInstance3D.new()
		if i % 2 == 0:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 3, 0.4)
			part.mesh = box
		else:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.13
			cylinder.bottom_radius = 0.13
			cylinder.height = 3
			part.mesh = cylinder
		part.material_override = material.duplicate()
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visibility_range_end = 160
		world.add_child(part)
		part.position = Vector3(1 + i * 0.6, 1.5, 2)
		if spread_structures and i >= 4:
			part.position.x += 16.0
		part.rotation = Vector3(0.08 * i, 0.15 * i, 0.04 * i)
		if i % 2 == 0:
			part.scale = Vector3.ONE * (1 + i * 0.1)
		else:
			part.scale = Vector3(1 + i * 0.1, 1, 0.9)
		part.create_trimesh_collision()
		bodies.append(part.get_child(0))
		if i % 2 == 0:
			originals.append(part)
		else:
			scaled_originals.append(part)
	# A duplicate shader resource is deliberately not on the reviewed allowlist.
	var excluded := MeshInstance3D.new()
	excluded.mesh = BoxMesh.new()
	var custom := ShaderMaterial.new()
	custom.shader = material.shader.duplicate()
	excluded.material_override = custom
	world.add_child(excluded)
	excluded.position = Vector3(1, -3, 2)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3, 2, 10)
	if spread_structures:
		camera.position = Vector3(11, 2, 24)
	var camera_distance := OS.get_environment("BATCH_REVIEW_CAMERA_DISTANCE")
	if not camera_distance.is_empty():
		assert(camera_distance.to_float() > 0.0)
		camera.position.z = 2.0 + camera_distance.to_float()
	camera.look_at(world.to_global(Vector3(11 if spread_structures else 3, 1.5, 2)))
	camera.current = true
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-35, -35, 0)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("before.png")) == OK)
	var original_indices := 0
	for original in originals:
		original_indices += original.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()
	# Full-scene captures exposed surface differences absent in this fixture.
	# Until resolved these shaders must keep their meshes and distance ranges.
	assert(Profile.batch_static_meshes(world) == 0)
	assert(world.get_node_or_null("MobileFacadeBatch") == null)
	var retained_indices := 0
	for original in originals:
		assert(original.mesh != null)
		assert(original.visibility_range_end == 160.0)
		retained_indices += original.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()
	assert(retained_indices == original_indices)
	for original in scaled_originals:
		assert(original.mesh != null)
	for body in bodies:
		assert(is_instance_valid(body) and body.is_inside_tree())
		assert(body.get_child(0).shape != null)
	assert(excluded.mesh != null)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("after.png")) == OK)
	print("MASONRY_BATCH_REVIEW_PASS concrete/masonry geometry, distance ranges, collision and excluded shader retained")
	quit()
