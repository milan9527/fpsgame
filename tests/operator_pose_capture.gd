extends SceneTree

# Inspect the shipped skin at several points in every clip, not only bone anchors.
func _initialize() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a graphical rendering server")
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.13, 0.16, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.86, 1.0)
	environment.environment.ambient_light_energy = 0.5
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.6
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0.5, 1.5, -5)
	camera.look_at(Vector3(0, 0.85, 0))
	camera.fov = 40
	camera.current = true
	var models: Array[Node3D] = []
	var players: Array[AnimationPlayer] = []
	var skins: Array[MeshInstance3D] = []
	var labels: Array[Label3D] = []
	for index in range(3):
		var model: Node3D = load("res://assets/operator.glb").instantiate()
		scene.add_child(model)
		model.position.x = (index - 1) * 1.1
		models.append(model)
		players.append(model.find_children("*", "AnimationPlayer", true, false)[0])
		skins.append(model.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.skin != null)[0])
		var label := Label3D.new()
		scene.add_child(label)
		label.position = Vector3(model.position.x, 1.95, 0)
		label.font_size = 32
		label.pixel_size = 0.0018
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		labels.append(label)
	var clips := ["Idle", "Reload", "CrouchReload", "Walk", "Run", "Jump",
		"CrouchIdle", "CrouchWalk", "Death", "DownedIdle", "DownedCrawl",
		"DownedDeath", "SeatedDriver", "SeatedPassenger", "SeatedDowned"]
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	var samples := 0
	for group in range(5):
		for index in range(3):
			var clip: String = clips[group * 3 + index]
			labels[index].text = clip
			var player := players[index]
			var names := Array(player.get_animation_list()).filter(func(n): return String(n).get_slice("/", String(n).get_slice_count("/") - 1) == clip)
			assert(names.size() == 1)
			player.play(names[0])
			for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
				player.seek(player.get_animation(names[0]).length * fraction, true)
				player.advance(0)
				await process_frame
				await RenderingServer.frame_post_draw
				var bounds := skins[index].bake_mesh_from_current_skeleton_pose().get_aabb()
				assert(bounds.position.is_finite() and bounds.size.is_finite())
				assert(bounds.size.x < 2.5 and bounds.size.y < 2.5 and bounds.size.z < 2.5)
				assert(bounds.size.length() > 0.8)
				samples += 1
			player.seek(player.get_animation(names[0]).length * 0.5, true)
			player.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join("poses-%d.png" % group)) == OK)
		if group == 0:
			for angle in [90, 180, 270]:
				for model in models:
					model.rotation_degrees.y = angle
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(output.path_join("turnaround-%d.png" % angle)) == OK)
			for model in models:
				model.rotation_degrees.y = 0
	print("OPERATOR_POSES_PASS clips=15 skin_samples=", samples)
	quit()
