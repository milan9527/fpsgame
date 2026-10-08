extends SceneTree

var Profile = load(OS.get_environment("MOBILE_PERFORMANCE_SCRIPT") if not OS.get_environment("MOBILE_PERFORMANCE_SCRIPT").is_empty() else "res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 600)
	var world := Node3D.new()
	root.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(18, 0, -9))
	var box := BoxMesh.new()
	box.size = Vector3(2, 4, 2)
	var shared := ArrayMesh.new()
	shared.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var shrub_cells := OS.get_environment("REVIEW_SHRUB_CELLS") == "1"
	if shrub_cells:
		# Exercise Android shrub grouping with a small deterministic fixture.
		shared.take_over_path("res://tests/review_shrub_palette_mobile.glb::ArrayMesh_fixture")
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.6, 0.4, 0.2)
	shared.surface_set_material(0, material)
	var shader_name := OS.get_environment("REVIEW_INSTANCE_SHADER")
	if not shader_name.is_empty():
		assert(shader_name in ["precast_concrete", "warehouse_concrete", "workshop_masonry"])
		var shader_material := ShaderMaterial.new()
		shader_material.shader = load("res://shaders/%s.gdshader" % shader_name)
		shared.surface_set_material(0, shader_material)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.32, 0.36, 0.40)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.75, 0.82, 0.94)
		environment.environment.ambient_light_energy = 0.7
		world.add_child(environment)
	var originals: Array[MeshInstance3D] = []
	var centers: Array[Vector3] = []
	var transforms: Array[Transform3D] = []
	var parent_bounds := AABB()
	for i in range(4):
		var part := MeshInstance3D.new()
		part.mesh = shared
		if OS.get_environment("REVIEW_DUPLICATE_OVERRIDES") == "1":
			part.material_override = shared.surface_get_material(0).duplicate()
		part.visibility_range_end = 160.0
		world.add_child(part)
		part.position = Vector3(2 + (4 if shrub_cells else 8) * i, 3, 2)
		if OS.get_environment("REVIEW_OVERRIDE_VARIANTS") == "1":
			part.position.x = 2.0 + 2.0 * i
			part.material_override = material.duplicate()
			part.material_override.albedo_color = Color.RED if i % 2 else Color.BLUE
		if shrub_cells and OS.get_environment("REVIEW_SHRUB_SINGLETON") == "1":
			part.position.x = [2.0, 10.0, 12.0, 14.0][i]
		part.rotation = Vector3(0.1 * i, 0.2 * i, 0)
		part.scale = Vector3(1, 1 + 0.1 * i, 1)
		part.create_trimesh_collision()
		originals.append(part)
		centers.append((part.global_transform * part.get_aabb()).get_center())
		transforms.append(part.transform)
		var bounds := part.transform * shared.get_aabb()
		parent_bounds = bounds if i == 0 else parent_bounds.merge(bounds)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(14, 9, 35)
	camera.look_at(world.to_global(Vector3(14, 3, 2)))
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join("before.png"))
	var separate_overrides := OS.get_environment("REVIEW_DUPLICATE_OVERRIDES") == "1" \
		or OS.get_environment("REVIEW_OVERRIDE_VARIANTS") == "1"
	assert(Profile.batch_static_meshes(world) == (0 if separate_overrides else 4))
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output.path_join("after.png"))
	if separate_overrides:
		for original in originals:
			assert(original.mesh == shared)
			assert(original.material_override != null)
			assert(original.get_child(0).get_child(0) is CollisionShape3D)
		for child in world.get_children():
			assert(not child is MultiMeshInstance3D)
		print("PASS: independent material overrides retain meshes, materials and collisions")
		quit()
		return
	var seen: Array[int] = []
	var batch_count := 0
	for child in world.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var batch := child as MultiMeshInstance3D
		batch_count += 1
		var center: Vector3 = batch.get_meta("mobile_distance_bounds", batch.global_transform * batch.get_aabb()).get_center()
		if shrub_cells and OS.get_environment("REVIEW_SHARED_SHRUB_DISTANCE") == "1":
			var expected_distance_bounds := world.global_transform * parent_bounds
			assert(batch.has_meta("mobile_distance_bounds"))
			assert(batch.get_meta("mobile_distance_bounds").is_equal_approx(expected_distance_bounds))
			var expected_end := 160.0
			for original_center in centers:
				expected_end = maxf(expected_end, 160.0 + expected_distance_bounds.get_center().distance_to(original_center))
			assert(is_equal_approx(batch.visibility_range_end, expected_end))
		var expected_bounds := AABB()
		for instance_index in range(batch.multimesh.instance_count):
			var transform := batch.multimesh.get_instance_transform(instance_index)
			var matched := -1
			for original_index in range(transforms.size()):
				if (batch.global_transform * transform).is_equal_approx(world.global_transform * transforms[original_index]):
					matched = original_index
					break
			assert(matched >= 0 and not seen.has(matched))
			if originals[matched].material_override is StandardMaterial3D:
				assert(batch.material_override is StandardMaterial3D)
				assert(batch.material_override.albedo_color == originals[matched].material_override.albedo_color)
			seen.append(matched)
			var bounds := transform * shared.get_aabb()
			expected_bounds = bounds if instance_index == 0 else expected_bounds.merge(bounds)
			if batch.visibility_range_end < 160.0 + center.distance_to(centers[matched]) - 0.001:
				push_error("MultiMesh cutoff does not enclose constituent visibility sphere")
				quit(1)
				return
		assert(batch.multimesh.custom_aabb.is_equal_approx(expected_bounds))
	var expected_batches := int(OS.get_environment("REVIEW_EXPECTED_BATCHES")) if not OS.get_environment("REVIEW_EXPECTED_BATCHES").is_empty() else 2
	assert(batch_count == expected_batches)
	assert(seen.size() == 4)
	for i in range(4):
		assert(originals[i].mesh == null)
		assert(originals[i].get_child(0) is StaticBody3D)
		assert(originals[i].get_child(0).get_child(0) is CollisionShape3D)
	print("PASS: MultiMesh explicit bounds, cutoff sphere coverage, transforms and collisions")
	quit()
