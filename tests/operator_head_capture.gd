extends SceneTree

# Close inspection of the exported head and equipment under neutral lighting.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.18, 0.20)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.9, 1.0)
	environment.environment.ambient_light_energy = 0.6
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	scene.add_child(light)
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.4
	var model: Node3D = load("res://assets/operator.glb").instantiate()
	scene.add_child(model)
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in player.get_animation_list():
		if String(clip).get_slice("/", String(clip).get_slice_count("/") - 1) == "Idle":
			player.play(clip)
			player.seek(0, true)
			player.pause()
			break
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 30
	camera.make_current()
	var views := {
		"front": Vector3(0, 1.68, -0.85),
		"side": Vector3(0.85, 1.68, -0.08),
		"rear": Vector3(0.3, 1.68, 0.8),
	}
	for label in views:
		camera.position = views[label]
		camera.look_at(Vector3(0, 1.62, 0), Vector3.UP)
		# Keep the inspected surface lit in every view. A fixed -Z key left
		# the front of the face in ambient-only light, hiding cloth contours.
		light.rotation = camera.rotation
		light.rotate_object_local(Vector3.RIGHT, deg_to_rad(-30))
		light.rotate_object_local(Vector3.UP, deg_to_rad(-25))
		for frame in range(3):
			await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
		print("HEAD_CAPTURE_SAVED ", label)
	quit()
