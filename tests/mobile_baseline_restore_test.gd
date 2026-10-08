extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	scene.position = Vector3(3, 0, 4)
	scene.rotation.y = 0.2
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	camera.cull_mask = 3
	var original_transform := camera.global_transform
	root.scaling_3d_scale = 0.6
	var shader := ShaderMaterial.new()
	shader.shader = Shader.new()
	shader.shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(0.3); }"
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = shader
	mesh.layers = 2
	scene.add_child(mesh)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = BoxMesh.new()
	batch.multimesh.instance_count = 1
	batch.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	scene.add_child(batch)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	var ground_material := ShaderMaterial.new()
	ground_material.shader = load("res://shaders/terrain_slopes_mobile.gdshader")
	ground.material_override = ground_material
	ground.layers = 3
	scene.add_child(ground)
	var family_nodes := {"terrain": ground}
	var family_materials := {"terrain": ground_material}
	var family_observed := {"terrain": false, "meadow": false, "road": false, "service": false}
	for family in ["meadow", "road", "service"]:
		var family_node := MeshInstance3D.new()
		family_node.mesh = PlaneMesh.new()
		var family_material := ShaderMaterial.new()
		var shader_name: String = {"meadow": "meadow_ground_mobile",
			"road": "road_surface_mobile", "service": "service_ground"}[family]
		family_material.shader = load("res://shaders/%s.gdshader" % shader_name)
		family_node.material_override = family_material
		family_node.position.x = 4.0 * family_nodes.size()
		scene.add_child(family_node)
		family_nodes[family] = family_node
		family_materials[family] = family_material
	# Observe each exclusion during actual frames, including StandardMaterial
	# MultiMeshes that shader-only substitution does not cover.
	var observed := {"ground": false, "other": false, "all": false,
		"instanced_other": false, "individual_other": false}
	var observe := func():
		var replaced: Array[String] = []
		for family in family_nodes:
			if family_nodes[family].material_override != family_materials[family]:
				replaced.append(family)
		if replaced.size() == 1 and mesh.material_override == shader:
			family_observed[replaced[0]] = true
		if ground.layers == 0 and mesh.layers == 2 and batch.layers == 1:
			observed.ground = true
		if ground.layers == 3 and mesh.layers == 0 and batch.layers == 0:
			observed.other = true
		if ground.layers == 3 and mesh.layers == 2 and batch.layers == 0:
			assert(mesh.material_override == shader)
			observed.instanced_other = true
		if ground.layers == 3 and mesh.layers == 0 and batch.layers == 1:
			assert(batch.material_override == null)
			observed.individual_other = true
		if ground.layers == 0 and mesh.layers == 0 and batch.layers == 0:
			observed.all = true
	RenderingServer.frame_post_draw.connect(observe)
	var profile = load("res://scripts/mobile_performance.gd")
	await profile.profile_render_baseline(camera)
	RenderingServer.frame_post_draw.disconnect(observe)
	assert(observed.ground and observed.other and observed.all)
	assert(observed.instanced_other and observed.individual_other)
	for family in family_nodes:
		assert(family_observed[family], "Missing isolated substitution: " + family)
		assert(family_nodes[family].material_override == family_materials[family])
		assert(family_nodes[family].layers == (3 if family == "terrain" else 1))
	assert(not profile.baseline_running)
	assert(camera.global_transform.is_equal_approx(original_transform))
	assert(camera.cull_mask == 3)
	assert(is_equal_approx(root.scaling_3d_scale, 0.6))
	assert(mesh.material_override == shader and mesh.layers == 2)
	assert(batch.material_override == null and batch.layers == 1)
	assert(ground.material_override == ground_material and ground.layers == 3)
	print("MOBILE_BASELINE_RESTORE_PASS isolated ground families geometry exclusion camera scale materials layers diagnostic flag")
	quit()
