extends SceneTree

# Real movement across the entrance ramp and joints; no position teleport per frame.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	actor.position = Vector3(35, 0.3, 43)
	actor.velocity = Vector3.ZERO
	actor.yaw = 0
	actor.pitch = -0.32
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var start: Vector3 = actor.position
	var records := []
	actor.move_input = Vector2(0, -1)
	for frame in range(120):
		await physics_frame
		actor.move_step(1.0 / 60.0)
		actor.render_frame(1.0 / 60.0, false, true, false)
		if frame % 20 == 0 or frame == 119:
			game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
			await process_frame
			await RenderingServer.frame_post_draw
			var image_name := "floor-walk-%03d.png" % frame
			assert(root.get_texture().get_image().save_png(output.path_join(image_name)) == OK)
			records.append({"frame": frame, "simulation_seconds": (frame + 1) / 60.0,
				"position": [actor.position.x, actor.position.y, actor.position.z],
				"yaw": actor.yaw, "pitch": actor.pitch, "image": image_name})
	var passed: bool = actor.position.z < 38.0 and actor.position.y > 0.15
	var file := FileAccess.open(output.path_join("floor-motion.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": records, "start": str(start),
		"end": str(actor.position), "passed": passed, "simulation_step": 1.0 / 60.0}, "\t"))
	file.close()
	print("WAREHOUSE_FLOOR_MOTION_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
