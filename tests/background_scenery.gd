extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use xvfb: headless MultiMesh readback is unavailable")
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var grove: MultiMeshInstance3D = world.get_node("BackgroundGroves")
	var ridge_count := 0
	# Raycast against temporary copies of the actual rendered triangle meshes.
	# Production scenery remains non-colliding and does not affect gameplay.
	for node in world.get_children():
		if not node.has_meta("ridge"): continue
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert(not normals.is_empty())
		for normal in normals:
			assert(normal.is_finite() and absf(normal.length() - 1.0) < 0.002 and normal.y > 0.0,
				"Ridge normals must remain finite, unit length and upward-facing")
		var body := StaticBody3D.new()
		body.collision_layer = 1 << 24
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = node.mesh.create_trimesh_shape()
		body.add_child(shape)
		world.add_child(body)
		body.transform = node.transform
		ridge_count += 1
	await physics_frame
	await physics_frame
	var maximum_error := 0.0
	var seedlings := 0
	for index in range(grove.multimesh.instance_count):
		var placement := grove.multimesh.get_instance_transform(index)
		var position := grove.to_global(placement.origin)
		var scale := placement.basis.get_scale().y
		assert(maxf(absf(position.x), absf(position.z)) >= 126.0, "Scenery tree inside arena")
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(position.x, 200, position.z), Vector3(position.x, -10, position.z), 1 << 24)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		var surface := -0.2
		if not hit.is_empty(): surface = maxf(surface, hit.position.y)
		# Stunted adult trees now overlap seedling sizes. Validate both supported
		# root burial depths against the rendered terrain, independently of size.
		if scale < 0.4: seedlings += 1
		var root_height := position.y - 4.5 * scale
		var error := minf(absf(root_height + 0.05 - surface),
			absf(root_height + 0.15 - surface))
		maximum_error = maxf(maximum_error, error)
		assert(error < 0.015, "Tree %d scale=%.4f root error=%.6f exceeds terrain tolerance" %
			[index, scale, error])
	assert(ridge_count == 18 and seedlings > 0)
	print("BACKGROUND_SCENERY_PASS ridges=%d trees=%d seedlings=%d max_root_error=%.6f" %
		[ridge_count, grove.multimesh.instance_count, seedlings, maximum_error])
	world.queue_free()
	await process_frame
	quit()
