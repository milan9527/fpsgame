extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# The dummy renderer returns identity for MultiMesh instance transforms.
	# Run under xvfb with a real renderer to verify the stored GPU transforms.
	if DisplayServer.get_name() == "headless":
		printerr("STATIC_GRASS_BATCH_REQUIRES_RENDERER: use xvfb-run with gl_compatibility or forward_plus")
		quit(2)
		return
	RenderingServer.render_loop_enabled = false
	var world := Node3D.new()
	root.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.27), Vector3(12, 3, -8))
	var imported := load("res://assets/realism/grass_fine.glb").instantiate() as Node3D
	var source: MeshInstance3D = imported.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := source.mesh
	var expected: Array[Transform3D] = []
	var instances: Array[MeshInstance3D] = []
	# Rotated and nonuniformly scaled parents exercise world/local conversion.
	for index in range(12):
		var parent := Node3D.new()
		world.add_child(parent)
		parent.transform = Transform3D(Basis(Vector3.UP, index * 0.21).scaled(Vector3(1.2, 0.8, 0.9)),
			Vector3(2 + index * 0.2, 0.3, 4))
		var node := MeshInstance3D.new()
		node.mesh = mesh
		parent.add_child(node)
		node.position = Vector3(0.2, 0.1, 0.3)
		node.layers = 3
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instances.append(node)
		expected.append(node.global_transform)
	var guarded := MeshInstance3D.new()
	guarded.mesh = mesh
	world.add_child(guarded)
	var collision := StaticBody3D.new()
	guarded.add_child(collision)
	var ranged := MeshInstance3D.new()
	ranged.mesh = mesh
	ranged.visibility_range_end = 20.0
	world.add_child(ranged)
	var overridden := MeshInstance3D.new()
	overridden.mesh = mesh
	overridden.set_surface_override_material(0, StandardMaterial3D.new())
	world.add_child(overridden)
	Visuals.batch_static_grass(world)
	var stats: Dictionary = world.get_meta("static_grass_batch_stats")
	assert(stats.replaced_mesh_nodes == 12, str(stats))
	assert(stats.batches == 1, str(stats))
	assert(guarded.get_parent() == world and collision.get_parent() == guarded)
	assert(ranged.get_parent() == world and overridden.get_parent() == world)
	var batch: MultiMeshInstance3D = world.find_children("*", "MultiMeshInstance3D", true, false)[0]
	assert(batch.multimesh.mesh == mesh)
	assert(batch.layers == 3 and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(batch.multimesh.instance_count == expected.size())
	var fixed_bounds := batch.multimesh.custom_aabb
	assert(fixed_bounds.has_volume())
	for index in range(expected.size()):
		var actual := batch.global_transform * batch.multimesh.get_instance_transform(index)
		if not actual.is_equal_approx(expected[index]):
			printerr("Grass transform mismatch ", index, " actual=", actual, " expected=", expected[index])
			quit(1)
			return
		# Check every source AABB corner independently in batch coordinates;
		# rotated/scaled parents and the cell anchor must not clip a tuft.
		for corner in range(8):
			var source_corner := mesh.get_aabb().get_endpoint(corner)
			var batch_corner := batch.to_local(expected[index] * source_corner)
			assert(fixed_bounds.grow(0.0001).has_point(batch_corner), str(batch_corner))
	for node in instances:
		assert(node.get_parent() == null)
	imported.free()
	print("STATIC_GRASS_BATCH_PASS instances=12 transforms/materials preserved; child/range/override excluded")
	quit()
