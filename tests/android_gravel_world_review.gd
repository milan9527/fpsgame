extends "mobile_view_geometry_inventory.gd"

# Full production world with Android asset branches. Desktop GL screenshots
# assess gravel appearance only; they are not Android performance acceptance.
func run() -> void:
	RenderingServer.render_loop_enabled = false
	android_branch_script("res://scripts/world_visuals.gd")
	var world_script := android_branch_script("res://scripts/world.gd")
	var world: Node3D = world_script.new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	Mobile = load("res://scripts/mobile_performance.gd")
	var configured: Dictionary = Mobile.configure_world(world)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var batches := []
	var inventory := []
	for spec in [["ServiceYardRecoveryAggregate", 3], ["ServiceLaneLooseAggregate", 2], ["RepairApronSurfaceAggregate", 3]]:
		var matches := world.find_children(spec[0], "MultiMeshInstance3D", true, false)
		assert(matches.size() == 1)
		var node: MultiMeshInstance3D = matches[0]
		var candidate: SphereMesh = node.multimesh.mesh
		var original: SphereMesh = candidate.duplicate()
		original.rings = spec[1]
		original.radius = 1.0
		var count := node.multimesh.visible_instance_count
		if count < 0:
			count = node.multimesh.instance_count
		batches.append({"node": node, "before": original, "after": candidate})
		inventory.append({"name": spec[0], "visible_instances": count,
			"before_triangles": triangles(original) * count,
			"after_triangles": triangles(candidate) * count})
	var poses := [
		{"name": "road", "eye": Vector3(2, 1.6, 61), "target": Vector3(0, 3.2, -85)},
		{"name": "yard", "eye": Vector3(15.5, 1.65, 40), "target": Vector3(18, 0.1, 46)},
		{"name": "lane", "eye": Vector3(12, 1.65, 50), "target": Vector3(16, 0.1, 45)},
	]
	for pose in poses:
		camera.position = pose.eye
		camera.look_at(pose.target)
		await process_frame
		for variant in ["before", "after"]:
			for batch in batches:
				batch.node.multimesh.mesh = batch[variant]
			RenderingServer.force_draw(false)
			var image := root.get_texture().get_image()
			assert(image != null and not image.is_empty())
			assert(image.save_png(output.path_join(pose.name + "-" + variant + ".png")) == OK)
			print("GRAVEL_WORLD_CAPTURE ", pose.name, " ", variant)
	var report := {"scope": "Full world, Android asset branches, desktop OpenGL; no objects hidden. Not phone FPS or gameplay acceptance.",
		"configured": configured, "batches": inventory, "poses": poses, "viewport": [1280, 800]}
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ANDROID_GRAVEL_WORLD_REVIEW_PASS")
	quit()
