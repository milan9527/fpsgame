extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var ridges := []
	# Read exported mesh vertices, independently of the procedural height function.
	for node in game.world.get_children():
		if not node.has_meta("ridge"): continue
		var profile: Vector3 = node.get_meta("ridge")
		var heights := []
		for z in range(129):
			var row := PackedFloat32Array()
			row.resize(129)
			row.fill(NAN)
			heights.append(row)
		var vertices: PackedVector3Array = node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			assert(is_finite(vertex.y) and vertex.y >= 0)
			var x := roundi(vertex.x / profile.x * 64 + 64)
			var z := roundi(vertex.z / profile.x * 64 + 64)
			assert(x >= 0 and x <= 128 and z >= 0 and z <= 128)
			heights[z][x] = vertex.y
		for row in heights:
			for elevation in row:
				assert(is_finite(elevation), "Rendered ridge grid must be complete")
		ridges.append({"origin": node.position, "profile": profile, "heights": heights})
	assert(ridges.size() == 18)
	var forest: MultiMesh = game.world.get_node("BackgroundGroves").multimesh
	assert(forest.instance_count > 1000)
	var max_error := 0.0
	for i in range(forest.instance_count):
		var placement := forest.get_instance_transform(i)
		var point := Vector2(placement.origin.x, placement.origin.z)
		assert(maxf(absf(point.x), absf(point.y)) >= 126, "Background trees stay outside arena")
		var size := placement.basis.get_scale().y
		var ground: float = load("res://scripts/world_visuals.gd").background_height(point, ridges)
		# Seedlings have uniform scale; mature crowns have independent width.
		var seedling := is_equal_approx(placement.basis.get_scale().x, size)
		var root_y := placement.origin.y - 4.5 * size + (0.05 if seedling else 0.15)
		max_error = maxf(max_error, absf(root_y - ground))
	assert(max_error < 0.002, "Tree anchors must match actual rendered ridge triangles")
	print("RIDGE_VISUAL_PASS ridges=18 trees=%d max_root_error=%.6f arena_exclusion=ok" % [forest.instance_count, max_error])
	quit()
