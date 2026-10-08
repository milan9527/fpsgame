extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mobile := preload("res://scripts/mobile_performance.gd")
	var world := Node3D.new()
	root.add_child(world)
	var source := MultiMeshInstance3D.new()
	source.name = "ServiceYardRecoveryAggregate"
	source.position = Vector3(3, 2, -5)
	source.rotation.y = 0.2
	source.material_override = StandardMaterial3D.new()
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.use_colors = true
	original.use_custom_data = true
	original.mesh = BoxMesh.new()
	original.instance_count = 12
	for i in range(original.instance_count):
		original.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.1 + i * 0.01)), Vector3(i * 3 - 18, i * 0.1, i % 3 * 17 - 17)))
		original.set_instance_color(i, Color(i / 12.0, 0.5, 0.25, 1))
		original.set_instance_custom_data(i, Color(i / 12.0, 0.1, 0.2, 0.3))
	source.multimesh = original
	world.add_child(source)
	var expected := {}
	for i in range(original.instance_count):
		expected[original.get_instance_transform(i)] = i
	var original_bounds := source.global_transform * source.get_aabb()
	var count := mobile.split_access_gravel(world)
	assert(count > 1)
	assert(source.multimesh == null)
	var seen := {}
	for batch: MultiMeshInstance3D in source.get_children():
		assert(batch.global_transform.is_equal_approx(source.global_transform))
		assert(batch.material_override == source.material_override)
		assert(batch.get_meta("mobile_distance_bounds").is_equal_approx(original_bounds))
		var cells := batch.multimesh
		assert(cells.mesh == original.mesh)
		for j in range(cells.instance_count):
			var placement := cells.get_instance_transform(j)
			assert(expected.has(placement))
			var i: int = expected[placement]
			assert(not seen.has(i))
			seen[i] = true
			assert(cells.get_instance_color(j).is_equal_approx(original.get_instance_color(i)))
			assert(cells.get_instance_custom_data(j).is_equal_approx(original.get_instance_custom_data(i)))
			var bounds: AABB = placement * cells.mesh.get_aabb()
			assert(cells.custom_aabb.grow(0.00001).encloses(bounds))
	assert(seen.size() == original.instance_count)
	assert(mobile.split_access_gravel(world) == 0, "Splitting must be idempotent")
	print("GRAVEL_CELLS_PASS: all 12 instances, attributes, transforms, material and distance bounds preserved")
	world.free()
	quit()
