extends SceneTree

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
	material.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	for i in range(12):
		var part := MeshInstance3D.new()
		if i % 2 == 0:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 3, 0.4)
			part.mesh = box
		else:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.13
			cylinder.bottom_radius = 0.13
			cylinder.radial_segments = [6, 12, 16, 24, 48, 64][i / 2]
			cylinder.height = 3
			part.mesh = cylinder
		part.material_override = material.duplicate()
		if i == 7:
			part.material_override.shader = preload("res://shaders/tank_paint.gdshader")
		if i == 9:
			part.material_override.shader = preload("res://shaders/silo_galvanized.gdshader")
		if i == 11:
			part.material_override.shader = preload("res://shaders/workyard_tank.gdshader")
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visibility_range_end = 160
		world.add_child(part)
		part.position = Vector3(1 + i * 0.6, 1.5, 2)
		part.rotation = Vector3(0.08 * i, 0.15 * i, 0.04 * i)
		if i % 2 == 0:
			part.scale = Vector3.ONE * (1 + i * 0.1)
		else:
			part.scale = Vector3(1 + i * 0.1, 1, 0.9)
		part.create_trimesh_collision()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4, 2, 12)
	camera.look_at(world.to_global(Vector3(4, 1.5, 2)))
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
	var measurements: Array[Dictionary] = []
	for child in world.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var before: int = child.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3
			var bounds: AABB = child.mesh.get_aabb()
			var collision: Shape3D = child.get_child(0).get_child(0).shape
			child.mesh.rings = 0
			var after: int = child.mesh.get_mesh_arrays()[Mesh.ARRAY_INDEX].size() / 3
			assert(after < before)
			assert(child.mesh.get_aabb().is_equal_approx(bounds))
			assert(child.get_child(0).get_child(0).shape == collision)
			measurements.append({"radial_segments": child.mesh.radial_segments, "triangles_before": before, "triangles_after": after})
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("after.png")) == OK)
	var report := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements, "\t"))
	report.close()
	print("CYLINDER_RINGS_REVIEW_PASS")
	quit()
