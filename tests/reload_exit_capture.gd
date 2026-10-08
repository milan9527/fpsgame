extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 0.2, 80)
	collision.shape = shape
	floor_body.add_child(collision)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	floor_mesh.mesh = box
	floor_body.add_child(floor_mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#647781")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var actor = load("res://scripts/actor.gd").new()
	world.add_child(actor)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 43
	camera.current = true
	await process_frame
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var frames: Array = []
	actor.move_input = Vector2(0, -1)
	for weapon in range(3):
		actor.character_animation.player.stop()
		actor.character_animation.active_clip = ""
		actor.character_animation.gait_phase = 0.0
		actor.character_animation.reload_gait_weight = 0.0
		actor.weapon = weapon
		actor.position = Vector3.ZERO
		actor.velocity = Vector3.ZERO
		actor.reload_left = actor.RELOAD[weapon]
		var end_frame := int(roundf(actor.RELOAD[weapon] * 60)) - 1
		for frame in range(end_frame + 13):
			await physics_frame
			actor.simulate(1.0 / 60.0)
			actor.render_frame(1.0 / 60.0, false, false, false)
			camera.position = actor.position + Vector3(2.8, 1.5, -3)
			camera.look_at(actor.position + Vector3(0, 0.95, 0), Vector3.UP)
			if frame >= end_frame - 5:
				await process_frame
				RenderingServer.force_draw()
				await RenderingServer.frame_post_draw
				var filename := "weapon-%d-frame-%03d.png" % [weapon, frame]
				root.get_texture().get_image().save_png(output.path_join(filename))
				frames.append({"weapon": weapon, "frame": frame, "image": filename,
					"reload_left": actor.reload_left, "clip": actor.character_animation.active_clip,
					"gait_phase": actor.character_animation.gait_phase,
					"actor": [actor.position.x, actor.position.y, actor.position.z],
					"camera_position": [camera.position.x, camera.position.y, camera.position.z],
					"camera_rotation": [camera.rotation.x, camera.rotation.y, camera.rotation.z],
					"grounded": actor.grounded})
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames": frames, "scope": "Three weapons walking across reload exit on isolated physical floor, 18 consecutive frames per weapon; fixed relative follow camera, compatibility renderer. Does not cover turns, foot locking or full-scene lighting."}, "\t"))
	print("RELOAD_EXIT_CAPTURE_PASS")
	world.free()
	quit()
