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
	material.shader = preload("res://shaders/shelter_structural_steel.gdshader")
	var originals: Array[MeshInstance3D] = []
	var bodies: Array[StaticBody3D] = []
	var scaled_originals: Array[MeshInstance3D] = []
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
		# Exercise explicitly opted-in generated surfaces alongside primitives.
		# Untagged ArrayMeshes must retain their resource (including imported LODs).
		if i == 2 or i == 3:
			var generated := SurfaceTool.new()
			generated.create_from(part.mesh, 0)
			part.mesh = generated.commit()
			if i == 2:
				part.set_meta("mobile_bake_static_surface", true)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.visibility_range_end = 160
		world.add_child(part)
		# Straddle the former 64m boundary within the larger primitive cell.
		part.position = Vector3(62 + i * 0.6, 1.5, 2)
		part.rotation = Vector3(0.08 * i, 0.15 * i, 0.04 * i)
		if i % 2 == 0:
			part.scale = Vector3.ONE * (1 + i * 0.1)
		else:
			part.scale = Vector3(1 + i * 0.1, 1, 0.9)
		if i == 3:
			# Uniform scale alone must not opt an untagged ArrayMesh into baking.
			part.scale = Vector3.ONE
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
	excluded.position = Vector3(62, -3, 2)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(64, 2, 10)
	camera.look_at(world.to_global(Vector3(64, 1.5, 2)))
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
	assert(Profile.batch_static_meshes(world) == 4)
	var merged_batches := 0
	for child in world.get_children():
		if child is MeshInstance3D and child != excluded \
			and child not in originals and child not in scaled_originals:
			merged_batches += 1
	assert(merged_batches == 1)
	for original in originals:
		assert(original.mesh == null)
	for original in scaled_originals:
		assert(original.mesh != null)
	for body in bodies:
		assert(is_instance_valid(body) and body.is_inside_tree())
		assert(body.get_child(0).shape != null)
	assert(excluded.mesh != null)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("after.png")) == OK)
	print("STEEL_BATCH_REVIEW_PASS four uniform surfaces merged, including tagged ArrayMesh; untagged/nonuniform geometry, collision and excluded shader retained")
	quit()
