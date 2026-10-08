extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Build and settle the scene without software-rendering intermediate frames.
	# The explicit force_draw below still captures the full viewport.
	RenderingServer.render_loop_enabled = false
	# Optional lower-resolution diagnostic; retain all world content and effects.
	var diagnostic_width := OS.get_environment("CAPTURE_WIDTH").to_int()
	if diagnostic_width > 0:
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(diagnostic_width, roundi(diagnostic_width * 0.625))
	var started := Time.get_ticks_msec()
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var service_shader_path := OS.get_environment("CAPTURE_SERVICE_SHADER_PATH")
	# Retain the resource so the world uses this diagnostic candidate.
	var service_shader: Shader
	if not service_shader_path.is_empty():
		service_shader = load("res://shaders/service_ground.gdshader")
		service_shader.code = FileAccess.get_file_as_string(service_shader_path)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	print("SPAWN_CAPTURE game_ready_ms=", Time.get_ticks_msec() - started)
	game.local_profile = null
	await process_frame
	game.start_solo()
	# Exercise the baked mobile terrain inside the complete desktop scene.
	# This diagnostic is not evidence of Android frame rate or final mobile visuals.
	var android_terrain := OS.get_environment("CAPTURE_ANDROID_TERRAIN") == "1"
	var terrain_replacements := 0
	if android_terrain:
		var cached_mesh: ArrayMesh = load("res://assets/android_terrain.res")
		var cached_shape: Shape3D = load("res://assets/android_terrain_collision.res")
		assert(cached_mesh != null and cached_shape != null)
		for node in root.find_children("ExcavatedTerrain", "MeshInstance3D", true, false):
			node.mesh = cached_mesh
			var shapes := node.find_children("*", "CollisionShape3D", true, false)
			assert(shapes.size() == 1)
			shapes[0].shape = cached_shape
			terrain_replacements += 1
		assert(terrain_replacements == 1)
	var disable_msaa := OS.get_environment("CAPTURE_DISABLE_MSAA") == "1"
	if disable_msaa:
		root.msaa_3d = Viewport.MSAA_DISABLED
	print("SPAWN_CAPTURE msaa=", root.msaa_3d)
	print("SPAWN_CAPTURE solo_ready_ms=", Time.get_ticks_msec() - started)
	var initial_position: Vector3 = game.actors[game.local_id].position
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	actor.reload_left = 0.0
	actor.switch_weapon(0)
	for frame in range(90):
		await physics_frame
		actor.simulate(1.0 / 60.0)
		actor.render_frame(1.0 / 60.0, false, true, false)
	game.ui.sight_aiming = false
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	# Isolate shadow cost without changing production settings or world geometry.
	# Diagnostic captures are explicitly labelled and cannot pass visual review.
	var shadows_disabled := OS.get_environment("CAPTURE_DISABLE_SHADOWS") == "1"
	var sun_bias := OS.get_environment("CAPTURE_SUN_BIAS")
	var sun_normal_bias := OS.get_environment("CAPTURE_SUN_NORMAL_BIAS")
	if not sun_normal_bias.is_empty():
		for node in root.find_children("*", "DirectionalLight3D", true, false):
			node.shadow_normal_bias = sun_normal_bias.to_float()
		print("SPAWN_CAPTURE diagnostic_sun_normal_bias=", sun_normal_bias)
	if not sun_bias.is_empty():
		for node in root.find_children("*", "DirectionalLight3D", true, false):
			node.shadow_bias = sun_bias.to_float()
		print("SPAWN_CAPTURE diagnostic_sun_bias=", sun_bias)
	var shadow_lights := 0
	if shadows_disabled:
		for node in root.find_children("*", "Light3D", true, false):
			if node.shadow_enabled:
				shadow_lights += 1
				node.shadow_enabled = false
		print("SPAWN_CAPTURE diagnostic_shadow_lights_disabled=", shadow_lights)
	var flat_materials := OS.get_environment("CAPTURE_FLAT_MATERIALS") == "1"
	var replace_shader := OS.get_environment("CAPTURE_REPLACE_SHADER")
	var replaced_materials := 0
	if flat_materials or not replace_shader.is_empty():
		var diagnostic_material := StandardMaterial3D.new()
		diagnostic_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		diagnostic_material.albedo_color = Color(0.45, 0.48, 0.4)
		for node in root.find_children("*", "GeometryInstance3D", true, false):
			var matches := flat_materials
			var materials: Array = [node.material_override, node.material_overlay]
			if node is MeshInstance3D and node.mesh:
				for surface in range(node.mesh.get_surface_count()):
					materials.append(node.get_active_material(surface))
			elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
				for surface in range(node.multimesh.mesh.get_surface_count()):
					materials.append(node.multimesh.mesh.surface_get_material(surface))
			for material in materials:
				if material is ShaderMaterial and material.shader and material.shader.resource_path == replace_shader:
					matches = true
			if not matches:
				continue
			node.material_override = diagnostic_material
			node.material_overlay = null
			replaced_materials += 1
		if not replace_shader.is_empty():
			assert(replaced_materials > 0, "Diagnostic shader selector did not match any geometry")
		print("SPAWN_CAPTURE diagnostic_flat_geometry_instances=", replaced_materials)
	for frame in range(4): await process_frame
	print("SPAWN_CAPTURE draw_begin_ms=", Time.get_ticks_msec() - started)
	RenderingServer.force_draw(false)
	print("SPAWN_CAPTURE draw_end_ms=", Time.get_ticks_msec() - started)
	assert(root.get_texture().get_image().save_png(output.path_join("default-spawn.png")) == OK)
	var record := {"name": "default-spawn", "actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"initial_position": [initial_position.x, initial_position.y, initial_position.z],
		"camera_position": [root.get_camera_3d().global_position.x, root.get_camera_3d().global_position.y, root.get_camera_3d().global_position.z],
		"yaw": actor.yaw, "pitch": actor.pitch, "viewport": [root.size.x, root.size.y], "weapon": 0, "ads": false,
		"diagnostic_shadows_disabled": shadows_disabled, "disabled_shadow_lights": shadow_lights,
		"diagnostic_sun_bias": sun_bias,
		"diagnostic_sun_normal_bias": sun_normal_bias,
		"diagnostic_flat_materials": flat_materials, "diagnostic_replace_shader": replace_shader,
		"diagnostic_service_shader_path": service_shader_path,
		"diagnostic_msaa_disabled": disable_msaa,
		"diagnostic_android_terrain": android_terrain,
		"terrain_replacements": terrain_replacements,
		"replaced_materials": replaced_materials}
	var file := FileAccess.open(output.path_join("spawn-camera-pose.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	print("DEFAULT_SPAWN_DIAGNOSTIC_PASS" if android_terrain or not sun_normal_bias.is_empty() or not sun_bias.is_empty() or disable_msaa or shadows_disabled or flat_materials or not replace_shader.is_empty() or not service_shader_path.is_empty() else "DEFAULT_SPAWN_REVIEW_PASS")
	quit()
