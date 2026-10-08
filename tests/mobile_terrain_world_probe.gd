extends SceneTree
var variant := "before" if "before" in OS.get_cmdline_user_args() else "after"
var scripts: Array[GDScript] = []
const OUT = "../artifacts/android-terrain-world-20260927-r156/fov85/"
func android_script(path: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace('OS.has_feature("android")', "true")
	script.take_over_path(path)
	assert(script.reload() == OK)
	scripts.append(script)
	return script
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	RenderingServer.render_loop_enabled = false
	assert(DisplayServer.get_name() != "headless")
	android_script("res://scripts/world_visuals.gd")
	var world: Node3D = android_script("res://scripts/world.gd").new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	var mobile := GDScript.new()
	mobile.source_code = FileAccess.get_file_as_string("res://scripts/mobile_performance.gd")
	assert(mobile.reload() == OK)
	scripts.append(mobile)
	mobile.configure_window(root)
	print("TERRAIN_WORLD configured window")
	mobile.configure_world(world)
	var matched := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.get_parent().get_parent() != null and (node.get_parent().name == "ExcavatedTerrain" or node.get_parent().get_parent().name == "ExcavatedTerrain"):
			matched += 1
			if variant == "after":
				node.lod_bias = 0.5
	assert(matched > 0)
	print("TERRAIN_WORLD configured chunks=", matched)
	root.size = Vector2i(1440, 900)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 85.0
	root.scaling_3d_scale = 0.65
	var results := []
	for view in ["spawn", "road", "slope"]:
		camera.position = {"spawn":Vector3(17, 1.65, 50), "road":Vector3(2, 1.6, 61), "slope":Vector3(0, 1.6, 35)}[view]
		camera.look_at({"spawn":Vector3(-1, 2.2, 66), "road":Vector3(0, 3.2, -85), "slope":Vector3(0, 1.6, 0)}[view])
		var shared_ranges := {}
		for node in world.find_children("*", "GeometryInstance3D", true, false):
			if not node.is_visible_in_tree() or node.get_meta("mobile_background_grove", false):
				continue
			if (node is MultiMeshInstance3D and node.multimesh == null) or (node is MeshInstance3D and node.mesh == null):
				continue
			var bounds: AABB = node.get_meta("mobile_distance_bounds", node.global_transform * node.get_aabb())
			var end: float = node.visibility_range_end
			if end == 0.0:
				end = mobile.detail_distance(bounds.size.length())
			if node.visibility_range_begin > 0.0 or end > 0.0:
				var distance := camera.position.distance_to(bounds.get_center())
				shared_ranges[node] = [node.visible, node.visibility_range_begin, node.visibility_range_end]
				var entry = mobile.DistanceEntry.new(node, bounds.get_center(), node.visibility_range_begin, end)
				node.visible = entry.grass_in_range(camera.position) if entry.grass_fade_squared > 0.0 else (distance >= node.visibility_range_begin and (end <= 0.0 or distance < end))
				node.visibility_range_begin = 0.0
				node.visibility_range_end = 0.0
		for frame in range(3):
			await process_frame
			RenderingServer.force_draw(false)
		var record := {"view":view,
			"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
		assert(root.get_texture().get_image().save_png(OUT+view+"-"+variant+".png") == OK)
		results.append(record)
		print("TERRAIN_WORLD ", variant, " ", record)
		for node in shared_ranges:
			node.visible = shared_ranges[node][0]
			node.visibility_range_begin = shared_ranges[node][1]
			node.visibility_range_end = shared_ranges[node][2]
	var file := FileAccess.open(OUT+variant+".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(), "terrain_chunks":matched, "results":results}, "\t"))
	quit()
