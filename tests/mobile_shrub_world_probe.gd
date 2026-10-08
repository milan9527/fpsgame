extends SceneTree
var variant := "before" if "before" in OS.get_cmdline_user_args() else "after"
var scripts: Array[GDScript] = []
const OUT = "../artifacts/android-shrub-world-20260927-r155/"
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
	print("SHRUB_WORLD configured window")
	var source_scene = load("res://assets/realism/verge_shrub_palette_mobile.glb").instantiate()
	var source: Mesh = source_scene.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var cluster_script := GDScript.new()
	var cluster_text := FileAccess.get_file_as_string("../tests/mobile_shrub_cluster_probe.gd")
	cluster_script.source_code = "extends RefCounted\n" + cluster_text.substr(cluster_text.find("func cluster("), cluster_text.find("func _initialize()") - cluster_text.find("func cluster("))
	assert(cluster_script.reload() == OK)
	var replacement: Mesh = cluster_script.new().cluster(source, 0.01)
	print("SHRUB_WORLD clustered mesh")
	var matched := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == source:
			matched += 1
			if variant == "after":
				node.mesh = replacement
	assert(matched == 10)
	source_scene.free()
	mobile.configure_world(world)
	print("SHRUB_WORLD configured world matches=", matched)
	root.size = Vector2i(1440, 900)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var results := []
	for view in ["road", "grove_far", "grove_mid", "grove_near"]:
		camera.position = {"road":Vector3(0, 1.6, 35), "grove_far":Vector3(0, 1.6, 29), "grove_mid":Vector3(-10, 1.6, 29), "grove_near":Vector3(-13, 1.6, 29)}[view]
		camera.look_at(Vector3(0, 1.6, 0) if view == "road" else Vector3(-16.3, 0.8, 25.6))
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
				node.visible = node.visible and distance >= node.visibility_range_begin and (end <= 0.0 or distance < end)
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
		print("SHRUB_WORLD ", variant, " ", record)
		for node in shared_ranges:
			node.visible = shared_ranges[node][0]
			node.visibility_range_begin = shared_ranges[node][1]
			node.visibility_range_end = shared_ranges[node][2]
	var file := FileAccess.open(OUT+variant+".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(), "matched_shrubs":matched, "results":results}, "\t"))
	quit()
