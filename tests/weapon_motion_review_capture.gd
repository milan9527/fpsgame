extends SceneTree

# Reload timelines at 10 Hz with fixed 60 Hz simulation, including both endpoints.
# Render sampling does not certify live input, networking or sub-frame contacts.
var game
var actor
var output: String
var records := []
var review_camera: Camera3D
var clip_frame := 0
var world_visible := false
var capture_started := 0
var compact := false
var culled_details := 0
var culled_instances := 0
var simplified_world := false
var simplified_meshes := 0

func simplify_background(node: Node, material: StandardMaterial3D) -> void:
	# Actors are direct children of game, outside this world-only subtree.
	if node is GeometryInstance3D:
		node.material_override = material
		simplified_meshes += 1
	if node is WorldEnvironment and node.environment != null:
		node.environment = node.environment.duplicate()
		node.environment.ssao_enabled = false
		node.environment.ssil_enabled = false
	for child in node.get_children():
		simplify_background(child, material)

func near_review(center: Vector3) -> bool:
	return center.distance_to(Vector3(0, 1, 90)) <= 12.0 or center.distance_to(Vector3(0, 1, 68)) <= 12.0

func vegetation_mesh(mesh: Mesh) -> bool:
	for asset in ["fir_full.glb", "fir_mid.glb", "fir_far.glb", "verge_birch.glb"]:
		if mesh.resource_path.contains(asset):
			return true
	return false

func cull_distant_details(node: Node) -> void:
	# Optional contact diagnosis only. Keep large terrain/building surfaces and
	# small geometry/trees within 12m of either first/third-person review position.
	if node is MeshInstance3D and node.mesh != null:
		var bounds: AABB = node.global_transform * node.get_aabb()
		var vegetation := vegetation_mesh(node.mesh)
		if bounds.size.length() < 8.0 or vegetation:
			var center := bounds.get_center()
			if center.distance_to(Vector3(0, 1, 90)) > 12.0 and center.distance_to(Vector3(0, 1, 68)) > 12.0:
				node.hide()
				culled_details += 1
	if node is MultiMeshInstance3D and node.multimesh != null:
		var original: MultiMesh = node.multimesh
		var retained := []
		var count := original.instance_count if original.visible_instance_count < 0 else original.visible_instance_count
		for index in range(count):
			var transform: Transform3D = original.get_instance_transform(index)
			var bounds: AABB = node.global_transform * transform * original.mesh.get_aabb()
			if (bounds.size.length() >= 8.0 and not vegetation_mesh(original.mesh)) or near_review(bounds.get_center()):
				retained.append(index)
		culled_instances += count - retained.size()
		var reduced := MultiMesh.new()
		reduced.transform_format = original.transform_format
		reduced.use_colors = original.use_colors
		reduced.use_custom_data = original.use_custom_data
		reduced.mesh = original.mesh
		reduced.instance_count = retained.size()
		for index in range(retained.size()):
			reduced.set_instance_transform(index, original.get_instance_transform(retained[index]))
			if original.use_colors:
				reduced.set_instance_color(index, original.get_instance_color(retained[index]))
			if original.use_custom_data:
				reduced.set_instance_custom_data(index, original.get_instance_custom_data(retained[index]))
		node.multimesh = reduced
	for child in node.get_children():
		cull_distant_details(child)

func diagnostic_lighting(node: Node) -> void:
	if node is Light3D:
		node.shadow_enabled = false
	for child in node.get_children():
		diagnostic_lighting(child)

func hide_geometry(node: Node) -> void:
	# Keep world lighting and physics; isolate silhouettes for contact review.
	if node is GeometryInstance3D:
		node.hide()
	for child in node.get_children():
		hide_geometry(child)

func _initialize() -> void:
	call_deferred("run")

func advance(frames: int, third: bool) -> void:
	for frame in range(frames):
		await physics_frame
		actor.simulate(1.0 / 60.0)
		actor.render_frame(1.0 / 60.0, false, not third, false)

func capture(label: String) -> void:
	var started := Time.get_ticks_msec()
	var timings := {}
	for frame in range(4):
		var wait_started := Time.get_ticks_msec()
		await process_frame
		timings["wait_%d_ms" % frame] = Time.get_ticks_msec() - wait_started
	var draw_started := Time.get_ticks_msec()
	RenderingServer.force_draw(false)
	timings["draw_ms"] = Time.get_ticks_msec() - draw_started
	var read_started := Time.get_ticks_msec()
	var image := root.get_texture().get_image()
	timings["readback_ms"] = Time.get_ticks_msec() - read_started
	var save_started := Time.get_ticks_msec()
	assert(image.save_png(output.path_join(label + ".png")) == OK)
	timings["save_ms"] = Time.get_ticks_msec() - save_started
	var cam := root.get_camera_3d()
	records.append({"name": label, "weapon": actor.weapon,
		"crouched": actor.crouched, "reload_left": actor.reload_left,
		"clip_frame": clip_frame, "clip_seconds": clip_frame / 60.0,
		"render_ms": Time.get_ticks_msec() - started,
		"capture_timings": timings,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"wall_ms": Time.get_ticks_msec() - capture_started,
		"ammo": actor.ammo, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"camera_position": [cam.global_position.x, cam.global_position.y, cam.global_position.z],
		"camera_rotation": [cam.global_rotation.x, cam.global_rotation.y, cam.global_rotation.z]})
	var file := FileAccess.open(output.path_join("contact-review.partial.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": false, "samples": records,
		"world_visible": world_visible,
		"background_materials_simplified": simplified_world,
		"simplified_world_meshes": simplified_meshes,
		"culled_detail_meshes": culled_details,
		"culled_detail_instances": culled_instances,
		"renderer": RenderingServer.get_current_rendering_method(),
		"shadows_disabled": compact,
		"viewport": [root.size.x, root.size.y]}, "\t"))
	file.close()
	print("CONTACT_CAPTURE_SAVED ", label)

func run() -> void:
	RenderingServer.render_loop_enabled = false
	output = OS.get_environment("CAPTURE_ARTIFACT_DIR")
	capture_started = Time.get_ticks_msec()
	compact = OS.get_environment("CONTACT_COMPACT") == "1"
	if compact:
		root.content_scale_size = Vector2i(640, 400)
		root.size = Vector2i(640, 400)
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	simplified_world = OS.get_environment("CONTACT_SIMPLIFY_WORLD") == "1"
	if simplified_world:
		var diagnostic_material := StandardMaterial3D.new()
		diagnostic_material.albedo_color = Color(0.37, 0.40, 0.33)
		diagnostic_material.roughness = 1.0
		simplify_background(game.world, diagnostic_material)
		root.msaa_3d = Viewport.MSAA_DISABLED
	if compact:
		# Contact diagnosis keeps the actual scene and material renderer, but
		# excludes costly shadow maps. Full-quality pose review remains separate.
		diagnostic_lighting(game.world)
	RenderingServer.render_loop_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	actor = game.actors[game.local_id]
	world_visible = OS.get_environment("CONTACT_WORLD_VISIBLE") == "1"
	if not world_visible:
		hide_geometry(game.world)
	elif OS.get_environment("CONTACT_CULL_DETAILS") == "1":
		cull_distant_details(game.world)
	for other in game.actors.values():
		if other != actor:
			other.hide()
	actor.aiming = false
	actor.reload_left = 0
	var requested: Array[String] = []
	var selection := OS.get_environment("CONTACT_REVIEW_CLIPS")
	if selection.is_empty():
		for view in ["first", "third-stand", "third-crouch"]:
			for weapon in [0, 1, 2]:
				requested.append("%s-weapon-%d" % [view, weapon])
	else:
		for label in selection.split(","):
			assert(not requested.has(label))
			assert(label in ["first-weapon-0", "first-weapon-1", "first-weapon-2",
				"third-stand-weapon-0", "third-stand-weapon-1", "third-stand-weapon-2",
				"third-crouch-weapon-0", "third-crouch-weapon-1", "third-crouch-weapon-2"])
			requested.append(label)
	for weapon in [0, 1, 2]:
		if not requested.has("first-weapon-%d" % weapon):
			continue
		actor.switch_weapon(weapon)
		await advance(60, false)
		assert(actor.weapon == weapon)
		await reload_clip("first-weapon-%d" % weapon, false)
	actor.position = Vector3(0, 0.3, 68)
	actor.velocity = Vector3.ZERO
	actor.local_view = false
	actor.body_mesh.visible = true
	game.ui.hide()
	review_camera = Camera3D.new()
	game.add_child(review_camera)
	review_camera.fov = 42
	review_camera.make_current()
	for crouch in [false, true]:
		actor.crouch = crouch
		actor.set_stance(crouch)
		for weapon in [0, 1, 2]:
			var label := "third-%s-weapon-%d" % ["crouch" if crouch else "stand", weapon]
			if not requested.has(label):
				continue
			actor.switch_weapon(weapon)
			await advance(60, true)
			review_camera.position = actor.position + Vector3(2.8, 1.5, -3)
			review_camera.look_at(actor.position + Vector3(0, 0.95, 0), Vector3.UP)
			if OS.get_environment("CONTACT_SIDE_CAMERA") == "1":
				var contact_height := 0.85 if crouch else 1.35
				review_camera.position = actor.position + Vector3(2.3, contact_height + 0.25, -0.6)
				review_camera.look_at(actor.position + Vector3(0, contact_height, -0.15), Vector3.UP)
			await reload_clip("third-%s-weapon-%d" % ["crouch" if crouch else "stand", weapon], true)
	var file := FileAccess.open(output.path_join("motion-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete": true, "samples": records,
		"requested_clips": requested, "full_suite_complete": requested.size() == 9,
		"world_visible": world_visible,
		"background_materials_simplified": simplified_world,
		"simplified_world_meshes": simplified_meshes,
		"culled_detail_meshes": culled_details,
		"culled_detail_instances": culled_instances,
		"renderer": RenderingServer.get_current_rendering_method(),
		"shadows_disabled": compact,
		"viewport": [root.size.x, root.size.y],
		"scope": "Only requested_clips; reload timelines at 10Hz. World visibility recorded separately. No locomotion, live-input timing or network certification.",
		"simulation_step": 1.0 / 60.0, "sample_step": 0.1}, "\t"))
	file.close()
	print("WEAPON_MOTION_REVIEW_PASS")
	# Release instances while the renderer is still alive, then drain queued
	# resource updates before SceneTree shutdown destroys shared materials.
	game.queue_free()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	quit()

func reload_clip(label: String, third: bool) -> void:
	var before: int = actor.ammo
	game.shoot(actor)
	assert(actor.ammo == before - 1)
	await advance(24, third)
	actor.reload_weapon()
	assert(actor.reload_left > 0)
	clip_frame = 0
	var end_frame := ceili(actor.RELOAD[actor.weapon] * 60) + 12
	while true:
		if not third:
			game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		await capture("%s-frame-%03d" % [label, clip_frame])
		if clip_frame >= end_frame:
			break
		var step := mini(6, end_frame - clip_frame)
		await advance(step, third)
		clip_frame += step
	assert(actor.reload_left <= 0 and actor.ammo == actor.CAPACITY[actor.weapon])
