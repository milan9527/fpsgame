extends SceneTree

# Measure the deformed mesh, not the ankle pivot or CharacterBody grounded flag.
# Isolated flat floor makes animation defects distinguishable from terrain offsets.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collision.shape = shape
	collision.position.y = -0.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var model = load("res://assets/operator.glb").instantiate()
	world.add_child(model)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await physics_frame
	var samples: Array = []
	var max_support_gap := -INF
	var min_gap := INF
	for clip in player.get_animation_list():
		var short_name: String = clip.get_slice("/", clip.get_slice_count("/") - 1)
		if short_name not in ["Idle", "Walk", "Run", "CrouchIdle", "CrouchWalk", "Reload", "CrouchReload"]:
			continue
		var length := player.get_animation(clip).length
		for frame in range(121):
			player.play(clip, 0)
			player.seek(length * frame / 120.0, true)
			skeleton.force_update_all_bone_transforms()
			await process_frame
			RenderingServer.force_draw(false)
			var soles := [Vector3(0, INF, 0), Vector3(0, INF, 0)]
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin == null: continue
				var baked: ArrayMesh = mesh.bake_mesh_from_current_skeleton_pose()
				for surface in range(baked.get_surface_count()):
					for vertex in baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						var side := 0 if vertex.x < 0 else 1
						var point: Vector3 = mesh.global_transform * vertex
						if point.y < soles[side].y: soles[side] = point
			var gaps: Array = []
			for sole in soles:
				assert(sole.is_finite())
				var query := PhysicsRayQueryParameters3D.create(sole + Vector3.UP, sole - Vector3.UP, 1)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
				assert(not hit.is_empty())
				gaps.append(sole.y - hit.position.y)
			var support_gap: float = minf(gaps[0], gaps[1])
			max_support_gap = maxf(max_support_gap, support_gap)
			min_gap = minf(min_gap, support_gap)
			samples.append({"clip": short_name, "time": length * frame / 120.0,
				"gap_m": gaps, "support_gap_m": support_gap})
	var result := {"samples": samples, "max_support_gap_m": max_support_gap, "min_gap_m": min_gap}
	var file := FileAccess.open(output.path_join("sole-cycle.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("SOLE_CYCLE_MEASURED samples=%d min_gap=%f max_support_gap=%f" % [samples.size(), min_gap, max_support_gap])
	if OS.get_environment("SOLE_ASSERT_CONTACT") == "1":
		assert(min_gap > -0.012, "Boot geometry penetrates the floor")
		assert(max_support_gap < 0.015, "Both boots float above flat ground")
		print("SOLE_CYCLE_CONTACT_PASS")
	quit()
