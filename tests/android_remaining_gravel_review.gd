extends "mobile_view_geometry_inventory.gd"

# Compare only the added Android compaction targets in the complete world.
# Desktop OpenGL is visual evidence, never Android frame-time acceptance.
func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	android_branch_script("res://scripts/world_visuals.gd")
	var world_script := android_branch_script("res://scripts/world.gd")
	var world: Node3D = world_script.new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	var batches := []
	for name in ["RepairApronSurfaceAggregate", "WestSillLooseDeposits", "CanopyDrainAggregate",
		"RepairShelterSplashStones"]:
		var matches := world.find_children(name, "MultiMeshInstance3D", true, false)
		assert(matches.size() == 1)
		var node: MultiMeshInstance3D = matches[0]
		batches.append({"node": node, "before": node.multimesh.mesh,
			"buffer": node.multimesh.buffer, "count": node.multimesh.instance_count,
			"material": node.material_override})
	Mobile = load("res://scripts/mobile_performance.gd")
	Mobile.configure_world(world)
	var inventory := []
	for batch in batches:
		batch["after"] = batch.node.multimesh.mesh
		assert(batch.after is ArrayMesh)
		assert(batch.node.multimesh.instance_count == batch.count)
		assert(batch.node.multimesh.buffer == batch.buffer)
		assert(batch.node.material_override == batch.material)
		inventory.append({"name": str(batch.node.name), "instances": batch.count,
			"before_triangles": triangles(batch.before) * batch.count,
			"after_triangles": triangles(batch.after) * batch.count})
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var poses := [
		{"name": "road", "eye": Vector3(2, 1.6, 61), "target": Vector3(0, 3.2, -85)},
		{"name": "apron", "eye": Vector3(12, 1.65, 50), "target": Vector3(16, 0.1, 45)},
		{"name": "sill", "eye": Vector3(9, 1.6, 37), "target": Vector3(11, 0.1, 30)},
		{"name": "splash", "eye": Vector3(10.9, 0.65, 31), "target": Vector3(11.8, 0.05, 29)},
		{"name": "canopy", "eye": Vector3(18, 1.6, 35), "target": Vector3(21.5, 0.1, 34)},
	]
	for pose in poses:
		var selected := OS.get_environment("GRAVEL_REVIEW_POSE")
		if not selected.is_empty() and pose.name != selected:
			continue
		camera.position = pose.eye
		camera.look_at(pose.target)
		await process_frame
		for variant in ["before", "after"]:
			for batch in batches:
				batch.node.multimesh.mesh = batch[variant]
			RenderingServer.force_draw(false)
			assert(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME) > 0)
			var image := root.get_texture().get_image()
			assert(image != null and not image.is_empty())
			assert(image.save_png(output.path_join(pose.name + "-" + variant + ".png")) == OK)
			print("REMAINING_GRAVEL_CAPTURE ", pose.name, " ", variant)
	var file := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"batches": inventory, "poses": poses,
		"scope": "Complete Android-branch world, desktop OpenGL; no phone FPS claim."}, "\t"))
	file.close()
	print("REMAINING_GRAVEL_REVIEW_PASS")
	quit()
