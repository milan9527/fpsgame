extends SceneTree
var variant := "before" if "before" in OS.get_cmdline_user_args() else "after"
var scripts: Array[GDScript] = []
var output_dir := OS.get_environment("GRASS_WORLD_REVIEW_DIR")
var frozen_shaders := {}
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
	assert(FileAccess.file_exists("res://project.godot"))
	assert(not output_dir.is_empty(), "Set GRASS_WORLD_REVIEW_DIR to a new evidence directory.")
	assert(not FileAccess.file_exists(output_dir.path_join(variant + ".json")), "Do not overwrite evidence.")
	assert(DirAccess.make_dir_recursive_absolute(output_dir) == OK)
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
	print("GRASS_WORLD configured window")
	mobile.configure_world(world)
	var matched := {}
	if variant == "after":
		matched = rebatch(world)
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		freeze_material(node.material_override)
		freeze_material(node.material_overlay)
		var mesh: Mesh = node.mesh if node is MeshInstance3D else (node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null)
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				freeze_material(mesh.surface_get_material(surface))
				if node is MeshInstance3D:
					freeze_material(node.get_surface_override_material(surface))
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
			RenderingServer.force_sync()
			RenderingServer.force_draw(true)
		var record := {"view":view,
			"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
		assert(root.get_texture().get_image().save_png(output_dir.path_join(view+"-"+variant+".png")) == OK)
		results.append(record)
		print("GRASS_WORLD ", variant, " ", record)
		for node in shared_ranges:
			node.visible = shared_ranges[node][0]
			node.visibility_range_begin = shared_ranges[node][1]
			node.visibility_range_end = shared_ranges[node][2]
	var file := FileAccess.open(output_dir.path_join(variant+".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(), "frozen_shader_count":frozen_shaders.size(), "grass_rebatch":matched, "results":results}, "\t"))
	file.close()
	world.queue_free()
	camera.queue_free()
	await process_frame
	await process_frame
	frozen_shaders.clear()
	RenderingServer.force_sync()
	RenderingServer.force_draw(true)
	print("GRASS_WORLD orphan audit")
	Node.print_orphan_nodes()
	quit()

func freeze_material(material: Material) -> void:
	if material == null:
		return
	if material is ShaderMaterial and material.shader != null:
		var shader: Shader = material.shader
		if not frozen_shaders.has(shader):
			frozen_shaders[shader] = true
			var expression := RegEx.new()
			assert(expression.compile("\\bTIME\\b") == OK)
			shader.code = expression.sub(shader.code, "0.0", true)
	if material.next_pass != null:
		freeze_material(material.next_pass)

# Runtime-only experiment: retain every Android root and its attributes, but
# group animated grass into 24 m cells to measure submission/overdraw tradeoffs.
func rebatch(world: Node3D) -> Dictionary:
	var groups := {}
	var originals := []
	var roots := 0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if not node.get_meta("mobile_animated_grass_fade", false):
			continue
		var mm: MultiMesh = node.multimesh
		assert(mm.visible_instance_count == -1)
		originals.append(node)
		for i in range(mm.instance_count):
			var transform: Transform3D = node.global_transform * mm.get_instance_transform(i)
			var cell := Vector2i(floori(transform.origin.x / 24.0), floori(transform.origin.z / 24.0))
			var key := str(cell) + ":" + str(mm.mesh.get_instance_id()) + ":" + str(node.material_override.get_instance_id())
			if not groups.has(key):
				groups[key] = {"source":node, "items":[]}
			groups[key].items.append([transform, mm.get_instance_color(i) if mm.use_colors else Color.WHITE, mm.get_instance_custom_data(i) if mm.use_custom_data else Color()])
			roots += 1
	var copied := 0
	for group in groups.values():
		var source: MultiMeshInstance3D = group.source
		var node: MultiMeshInstance3D = source.duplicate(0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = source.multimesh.use_colors
		mm.use_custom_data = source.multimesh.use_custom_data
		mm.mesh = source.multimesh.mesh
		mm.instance_count = group.items.size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, group.items[i][0])
			if mm.use_colors: mm.set_instance_color(i, group.items[i][1])
			if mm.use_custom_data: mm.set_instance_custom_data(i, group.items[i][2])
			assert(mm.get_instance_transform(i).is_equal_approx(group.items[i][0]))
			copied += 1
		node.multimesh = mm
		world.add_child(node)
		node.global_transform = Transform3D.IDENTITY
		if node.has_meta("mobile_distance_bounds"): node.remove_meta("mobile_distance_bounds")
	for node in originals:
		node.get_parent().remove_child(node)
		node.free()
	assert(copied == roots)
	return {"old_batches":originals.size(), "new_batches":groups.size(), "roots":roots, "copied":copied, "cell_m":24}
