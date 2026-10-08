extends SceneTree

# Identical poses can be run against both old and new PCKs.
func _initialize() -> void:
	call_deferred("run")

func trace_step(label: String) -> void:
	print("CAPTURE_TRACE ms=", Time.get_ticks_msec(), " ", label)

func run() -> void:
	print("ENVIRONMENT_REVIEW loading game")
	RenderingServer.render_loop_enabled = false
	var game_script = load("res://scripts/game.gd")
	trace_step("game script loaded")
	var game = game_script.new()
	trace_step("game instantiated")
	root.add_child(game)
	trace_step("game added to tree")
	game.local_profile = null
	trace_step("initial process_frame begin")
	await process_frame
	trace_step("initial process_frame end")
	game.start_solo()
	# Keep captures explicit after scene setup; force_draw is called below.
	RenderingServer.render_loop_enabled = false
	print("ENVIRONMENT_REVIEW world ready")
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	# Pausing the game also pauses remote actor gravity. Settle the whole
	# roster before freezing the scene so airborne spawn positions aren't
	# mistaken for broken character grounding.
	for frame in range(180):
		await physics_frame
		for participant in game.actors.values():
			participant.simulate(1.0 / 60.0)
			participant.render_frame(1.0 / 60.0, false, participant == actor, false)
	# Separate competing causes at the same camera; these are capture-only
	# overrides, never changes to the shipped world's lighting or materials.
	var road_diagnostic := OS.get_environment("REVIEW_ROAD_DIAGNOSTIC")
	var diagnostic_changes := 0
	assert(road_diagnostic in ["", "road-no-cast", "sun-no-shadow", "flat-road", "hide-cross-road", "road-no-bump"])
	for node in game.world.find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if not material is ShaderMaterial or material.shader == null:
			continue
		if not material.shader.resource_path.ends_with("/road_surface.gdshader"):
			continue
		if road_diagnostic == "road-no-cast":
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			diagnostic_changes += 1
		elif road_diagnostic == "road-no-bump":
			var diagnostic_material: ShaderMaterial = material.duplicate()
			var diagnostic_shader := Shader.new()
			var original: String = material.shader.code
			var bump_line := "NORMAL=normalize(NORMAL-gradient+NORMAL*dot(NORMAL,gradient));"
			if not original.contains(bump_line):
				bump_line = "NORMAL=normalize(abs(determinant)*NORMAL-sign(determinant)*(dFdx(height)*r1+dFdy(height)*r2));"
			assert(original.contains(bump_line))
			diagnostic_shader.code = original.replace(bump_line, "// Bump disabled for this diagnostic only.")
			diagnostic_material.shader = diagnostic_shader
			node.material_override = diagnostic_material
			diagnostic_changes += 1
		elif road_diagnostic == "flat-road":
			var flat := StandardMaterial3D.new()
			flat.albedo_color = Color(0.11, 0.12, 0.12)
			flat.roughness = 0.95
			node.material_override = flat
			diagnostic_changes += 1
		elif road_diagnostic == "hide-cross-road" and material.get_shader_parameter("east_west"):
			node.hide()
			diagnostic_changes += 1
	if road_diagnostic == "sun-no-shadow":
		for node in game.world.find_children("*", "DirectionalLight3D", true, false):
			node.shadow_enabled = false
			diagnostic_changes += 1
	if not road_diagnostic.is_empty():
		assert(diagnostic_changes > 0)
		print("ROAD_DIAGNOSTIC mode=", road_diagnostic, " changed_nodes=", diagnostic_changes)
	# Diagnostic A/B: remove only the legacy 12 mm decorative floor strips.
	var hidden_joints := 0
	if OS.get_environment("REVIEW_HIDE_FLOOR_JOINTS") == "1":
		for node in game.world.find_children("*", "MeshInstance3D", true, false):
			if node.mesh is BoxMesh and (node.mesh.size.is_equal_approx(Vector3(0.012, 0.002, 12.4)) or node.mesh.size.is_equal_approx(Vector3(15.4, 0.002, 0.012))):
				node.hide()
				hidden_joints += 1
		for node in game.world.find_children("*", "MultiMeshInstance3D", true, false):
			if not node.multimesh.mesh is BoxMesh:
				continue
			for index in range(node.multimesh.instance_count):
				var instance: Transform3D = node.multimesh.get_instance_transform(index)
				var size := instance.basis.get_scale()
				if size.is_equal_approx(Vector3(0.012, 0.002, 12.4)) or size.is_equal_approx(Vector3(15.4, 0.002, 0.012)):
					instance.basis = Basis.from_scale(Vector3.ZERO)
					node.multimesh.set_instance_transform(index, instance)
					hidden_joints += 1
		assert(hidden_joints > 0)
		print("REVIEW_HIDDEN_FLOOR_JOINTS=", hidden_joints)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var diagnostic_file := FileAccess.open(output.path_join("road-diagnostic.json"), FileAccess.WRITE)
	diagnostic_file.store_string(JSON.stringify({"mode": road_diagnostic, "changed_nodes": diagnostic_changes}))
	diagnostic_file.close()
	var poses := [
		{"name": "drainage-north-crossing", "at": Vector3(5.5, 0.05, 23), "target": Vector3(10, 0.5, 28)},
		{"name": "service-approach", "at": Vector3(17, 0.00010254, 50), "target": Vector3(17, 3.6, 30)},
		{"name": "precast-yard", "at": Vector3(-22, 0.05, 41), "target": Vector3(-19, 1.5, 34)},
		{"name": "waiting-shelter-entrance", "at": Vector3(8, 0.05, 87), "target": Vector3(16, 1.8, 84)},
		{"name": "arrival-canopy-entrance", "at": Vector3(-12, 0.05, 76), "target": Vector3(-12, 2.0, 64)},
		{"name": "repair-shelter-entrance", "at": Vector3(15.5, 0.05, 39), "target": Vector3(15.5, 2.3, 27)},
		{"name": "repair-shelter-side", "at": Vector3(7.5, 0.05, 37), "target": Vector3(14.0, 1.9, 29.5)},
		{"name": "silo-eye-level", "at": Vector3(-43, 0.05, -5), "target": Vector3(-54, 5, -18)},
		{"name": "grass-bank-eye-level", "at": Vector3(-26, 0.05, 63), "target": Vector3(-26, 0.6, 50)},
		{"name": "spawn-environment", "at": Vector3(17, 0.05, 50), "target": Vector3(35, 0.9273, 34)},
		{"name": "utility-station-entrance", "at": Vector3(-42, 0.05, -20), "target": Vector3(-42, 2.5, -35)},
		{"name": "west-workshop-approach", "at": Vector3(-17, 0.05, 49), "target": Vector3(-42, 3.8, 34)},
		{"name": "west-workshop-entrance", "at": Vector3(-42, 0.05, 44), "target": Vector3(-42, 1.9, 34)},
		{"name": "workshop-service-bay", "at": Vector3(-28, 0.05, 44), "target": Vector3(-31, 2.8, 32)},
		{"name": "depot-approach", "at": Vector3(17, 0.05, 46), "target": Vector3(31, 2.2, 34)},
		{"name": "depot-canopy", "at": Vector3(23.5, 0.05, 42), "target": Vector3(25, 2.0, 31)},
		{"name": "depot-entrance-close", "at": Vector3(35, 0.05, 44), "target": Vector3(35, 1.9, 34)},
		{"name": "terrain-wide", "at": Vector3(17, 0.05, 50), "target": Vector3(-46, 12, -90)},
		{"name": "road-horizon", "at": Vector3(2, 0.05, 61), "target": Vector3(0, 3.2, -85)},
		{"name": "depot-interior-fixture", "at": Vector3(35, 0.05, 38), "target": Vector3(35, 3.85, 34)},
		{"name": "depot-interior-floor", "at": Vector3(35, 0.05, 38), "target": Vector3(35, 0.3, 32)}
	]
	# Pick the same seeded foreground tree in both the source and previous PCK.
	var nearest: Node3D = null
	var distance := INF
	for child in game.world.get_children():
		if child is Node3D and str(child.name).begins_with("fir_near"):
			var candidate: float = child.position.distance_to(Vector3(17, 0, 50))
			if candidate < distance:
				nearest = child
				distance = candidate
	assert(nearest != null)
	poses.append({"name": "forest-eye-level", "at": nearest.position + Vector3(0, 0.05, 10),
		"target": nearest.position + Vector3(0, 4, 0)})
	var records := []
	for pose in poses:
		var selected := OS.get_environment("REVIEW_POSES")
		if not selected.is_empty() and not pose.name in selected.split(","):
			continue
		actor.position = pose.at
		var delta: Vector3 = pose.at + Vector3(0, 1.6, 0) - pose.target
		actor.yaw = atan2(delta.x, delta.z)
		actor.pitch = -atan2(delta.y, Vector2(delta.x, delta.z).length())
		if pose.name == "service-approach":
			actor.yaw = 0.0
			actor.pitch = 0.1
		if pose.name == "spawn-environment":
			actor.yaw = atan2(-18, 16)
			actor.pitch = -0.03
		records.append({"name": pose.name, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
			"target": [pose.target.x, pose.target.y, pose.target.z], "yaw_radians": actor.yaw,
			"pitch_radians": actor.pitch, "eye_offset_y": 1.6, "viewport": [1280, 800]})
		for frame in range(60):
			actor.render_frame(1.0 / 60.0, false, true, false)
		var eye: Vector3 = actor.camera.global_position
		var forward: Vector3 = -actor.camera.global_basis.z
		records.back()["camera_global_position"] = [eye.x, eye.y, eye.z]
		records.back()["camera_forward"] = [forward.x, forward.y, forward.z]
		game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		print("ENVIRONMENT_REVIEW drawing ", pose.name)
		# Persist pose before GPU work so a timed-out capture remains diagnosable.
		var checkpoint := FileAccess.open(output.path_join("environment-camera-poses.json"), FileAccess.WRITE)
		checkpoint.store_string(JSON.stringify(records, "\t"))
		checkpoint.close()
		for frame in range(2):
			trace_step(pose.name + " process_frame_begin_" + str(frame))
			await process_frame
			trace_step(pose.name + " process_frame_end_" + str(frame))
		trace_step(pose.name + " force_draw_begin")
		RenderingServer.force_draw(false)
		trace_step(pose.name + " force_draw_end")
		var image := root.get_texture().get_image()
		trace_step(pose.name + " get_image_end")
		assert(image.save_png(output.path_join(pose.name + ".png")) == OK)
		trace_step(pose.name + " save_png_end")
		print("ENVIRONMENT_REVIEW saved ", pose.name)
	var record_file := FileAccess.open(output.path_join("environment-camera-poses.json"), FileAccess.WRITE)
	record_file.store_string(JSON.stringify(records, "\t"))
	record_file.close()
	print("ENVIRONMENT_REVIEW_CAPTURE_PASS frames=", records.size())
	quit()
