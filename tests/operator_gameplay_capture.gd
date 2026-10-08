extends SceneTree

# Actual actor materials, weapon attachment and world lighting; manual review required.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Software rendering is expensive for the full world. Deferred skeleton
	# updates need scene frames, but only the final pose needs a rendered frame.
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	actor.local_view = false
	actor.body_mesh.visible = true
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = 0.0
	actor.pitch = 0.0
	actor.grounded = true
	actor.velocity = Vector3.ZERO
	game.ui.hide()
	var review_camera := Camera3D.new()
	game.add_child(review_camera)
	review_camera.fov = 42.0
	review_camera.make_current()
	var count := 0
	for stance in ["idle", "crouch", "reload", "downed"]:
		actor.crouched = stance == "crouch"
		actor.downed = stance == "downed"
		actor.reload_left = actor.RELOAD[actor.weapon] * 0.5 if stance == "reload" else 0.0
		for frame in range(12):
			actor.render_frame(1.0 / 60.0, false, false, false)
			# Let deferred skeleton updates finish before sampling the next pose.
			await process_frame
		for angle in [0, 90, 180]:
			var radians := deg_to_rad(float(angle))
			var focus: Vector3 = actor.position + Vector3(0, 0.95, 0)
			review_camera.position = actor.position + Vector3(sin(radians) * 3.8, 1.5, -cos(radians) * 3.8)
			review_camera.look_at(focus)
			for frame in range(4):
				await process_frame
			review_camera.make_current()
			assert(root.get_camera_3d() == review_camera)
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(output.path_join("%s-%d.png" % [stance, angle])) == OK)
			count += 1
			print("OPERATOR_GAMEPLAY_CAPTURE_SAVED stance=%s angle=%d camera=%s" % [stance, angle, review_camera.global_position])
	print("OPERATOR_GAMEPLAY_CAPTURE_PASS frames=%d; visual inspection required" % count)
	quit()
