extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Use xvfb-run with gl_compatibility to verify MultiMesh transforms")
		quit(2)
		return
	RenderingServer.render_loop_enabled = false
	# Empty categories must not load a source asset or allocate temporary nodes.
	var empty_world := Node3D.new()
	root.add_child(empty_world)
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	Visuals.batch_facade(empty_world, "missing_empty_fixture", "absent_placements")
	empty_world.set_meta("empty_placements", [])
	Visuals.batch_facade(empty_world, "missing_empty_fixture", "empty_placements")
	assert(empty_world.get_child_count() == 0)
	assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == nodes_before)
	empty_world.free()
	print("EMPTY_FACADE_PASS absent/empty categories skip asset loading and temporary nodes")
	var world := Node3D.new()
	root.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(18, 4, -9))
	var placements := [
		Transform3D(Basis(Vector3.UP, 0.7), Vector3(-42, 2, -30)),
		Transform3D(Basis(Vector3.UP, -0.4), Vector3(-40, 3, -29)),
		Transform3D(Basis(Vector3.UP, 1.2), Vector3(44, 2, 30))]
	var source: Node3D = load("res://assets/realism/window_shutter.glb").instantiate()
	world.add_child(source)
	var expected := {}
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var key := part.mesh.get_instance_id()
		if not expected.has(key): expected[key] = []
		var local := world.global_transform.affine_inverse() * part.global_transform
		for placement: Transform3D in placements:
			expected[key].append(world.global_transform * placement * local)
	world.remove_child(source)
	world.set_meta("shutter_placements", placements)
	Visuals.batch_facade(world, "window_shutter", "shutter_placements")
	var count := 0
	for batch: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
		var remaining: Array = expected[batch.multimesh.mesh.get_instance_id()]
		assert(batch.multimesh.instance_count <= 2, "Distant facades must be culled separately")
		for index in range(batch.multimesh.instance_count):
			var actual := batch.global_transform * batch.multimesh.get_instance_transform(index)
			var match_index := -1
			for candidate in range(remaining.size()):
				if actual.is_equal_approx(remaining[candidate]):
					match_index = candidate
					break
			assert(match_index >= 0, "Facade moved during batching")
			var fixed_bounds := batch.multimesh.custom_aabb
			assert(fixed_bounds != AABB(), "Static facade bounds must be supplied")
			for corner in range(8):
				var point := batch.to_local(remaining[match_index] * batch.multimesh.mesh.get_aabb().get_endpoint(corner))
				assert(fixed_bounds.grow(0.0001).has_point(point), "Facade bounds clip geometry")
			remaining.remove_at(match_index)
			count += 1
	for remaining: Array in expected.values():
		assert(remaining.is_empty(), "Facade lost during batching")
	assert(count > 0)
	source.free()
	print("FACADE_BATCH_PASS instances=", count, " separated cells; transformed world and rotated placements preserved")
	# Check non-cubic beams after rotation as well as their spatial partition.
	var details_world := Node3D.new()
	root.add_child(details_world)
	details_world.transform = world.transform
	var material := StandardMaterial3D.new()
	var expected_details: Array[Transform3D] = []
	for placement: Transform3D in placements:
		var detail := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 0.2, 0.1)
		detail.mesh = box
		detail.material_override = material
		detail.set_meta("visual_batch", "test-beam")
		details_world.add_child(detail)
		detail.transform = placement
		expected_details.append(detail.global_transform * Transform3D(Basis.from_scale(box.size), Vector3.ZERO))
	Visuals.batch_details(details_world)
	var detail_count := 0
	for batch: MultiMeshInstance3D in details_world.find_children("*", "MultiMeshInstance3D", true, false):
		assert(batch.material_override == material)
		assert(batch.multimesh.instance_count <= 2)
		for index in range(batch.multimesh.instance_count):
			var actual := batch.global_transform * batch.multimesh.get_instance_transform(index)
			var match_index := -1
			for candidate in range(expected_details.size()):
				if actual.is_equal_approx(expected_details[candidate]):
					match_index = candidate
					break
			assert(match_index >= 0, "Rotated beam geometry changed")
			var fixed_bounds := batch.multimesh.custom_aabb
			assert(fixed_bounds.size.length() > 0.0)
			for corner in range(8):
				var point := batch.to_local(expected_details[match_index] * batch.multimesh.mesh.get_aabb().get_endpoint(corner))
				assert(fixed_bounds.grow(0.001).has_point(point), "Detail bounds exclude transformed geometry")
			expected_details.remove_at(match_index)
			detail_count += 1
	assert(detail_count == 3 and expected_details.is_empty())
	print("DETAIL_BATCH_PASS rotated non-cubic geometry and materials preserved across cells")
	quit()
