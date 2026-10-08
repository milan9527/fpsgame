extends SceneTree

const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; // tuft_variation colony_hash\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	for active in [-1, 0, 1, 16, 17, 33, 64]:
		var world := Node3D.new()
		root.add_child(world)
		var node := MultiMeshInstance3D.new()
		node.name = "GrassActivePrefix"
		var original := MultiMesh.new()
		original.transform_format = MultiMesh.TRANSFORM_3D
		original.use_colors = true
		original.use_custom_data = true
		original.mesh = QuadMesh.new()
		original.instance_count = 64
		for i in range(64):
			original.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(i, i * 0.1, -i)))
			original.set_instance_color(i, Color(i / 64.0, 0.5, 0.75, 1))
			original.set_instance_custom_data(i, Color(0.3, i / 64.0, 0, 1))
		original.visible_instance_count = active
		node.multimesh = original
		node.material_override = material
		world.add_child(node)
		var stats := Mobile.configure_world(world)
		var expected_active: int = 64 if active < 0 else active
		var expected := ceili(expected_active / 16.0)
		assert(stats.grass_before == expected_active)
		assert(stats.grass_after == expected)
		assert(node.multimesh.instance_count == expected)
		assert(original.instance_count == 64 and original.visible_instance_count == active)
		for i in range(expected):
			assert(node.multimesh.get_instance_transform(i) == original.get_instance_transform(i * 16))
			assert(node.multimesh.get_instance_color(i) == original.get_instance_color(i * 16))
			assert(node.multimesh.get_instance_custom_data(i) == original.get_instance_custom_data(i * 16))
		world.free()
	print("ANDROID_GRASS_ACTIVE_INSTANCES_PASS cases=7 transforms/colors/custom_data preserved")
	quit()
