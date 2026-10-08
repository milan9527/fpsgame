extends SceneTree

const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for child in node.get_children():
		var mesh := find_mesh(child)
		if mesh != null:
			return mesh
	return null

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var source := ShaderMaterial.new()
	source.shader = load("res://shaders/grass.gdshader")
	var source_code := source.shader.code
	var nodes: Array[MultiMeshInstance3D] = []
	for asset in ["grass", "grass_fine", "grass_broadleaf", "grass", "grass"]:
		var model: Node = load("res://assets/realism/%s.glb" % asset).instantiate()
		var mesh := find_mesh(model)
		assert(mesh != null)
		var short_grass := Mobile.grass_can_skip_dry_tips(mesh)
		assert(short_grass == (asset == "grass"))
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = mesh
		node.multimesh.instance_count = 1
		node.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
		node.material_override = source
		if nodes.size() == 4:
			node.material_override = source.duplicate()
			node.material_override.set_shader_parameter("wind_strength", 0.041)
		world.add_child(node)
		nodes.append(node)
		model.free()
	var stats := Mobile.configure_world(world)
	assert(stats.grass_before == 5 and stats.grass_after == 5)
	assert(nodes[0].material_override == nodes[3].material_override)
	assert(nodes[1].material_override == nodes[2].material_override)
	assert(nodes[0].material_override != nodes[1].material_override)
	assert(nodes[0].material_override != nodes[4].material_override)
	assert(nodes[0].material_override.shader == nodes[4].material_override.shader)
	assert(is_equal_approx(nodes[4].material_override.get_shader_parameter("wind_strength"), 0.041))
	assert(source.get_shader_parameter("wind_strength") != 0.041)
	for i in range(nodes.size()):
		var material: ShaderMaterial = nodes[i].material_override
		assert(material != source)
		assert(material.shader.code.begins_with("#define SHORT_GRASS") == (i == 0 or i >= 3))
		assert(material.get_shader_parameter("fade_begin") == 16.0)
		assert(material.get_shader_parameter("fade_end") == 24.0)
	assert(source.shader.code == source_code)
	assert(not Mobile.grass_can_skip_dry_tips(null))
	assert(not Mobile.grass_can_skip_dry_tips(ArrayMesh.new()))
	var tall := BoxMesh.new()
	tall.size = Vector3(1, 1, 1)
	assert(not Mobile.grass_can_skip_dry_tips(tall))
	world.free()
	print("ANDROID_GRASS_MATERIAL_VARIANTS_PASS actual_assets=3 shared_source_preserved=true")
	quit()
