extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Prepare the fixed review pose before drawing the expensive full scene.
	# This still renders the real viewport, including geometry, shaders and HUD.
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
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = atan2(-18, 16)
	actor.pitch = -0.03
	actor.reload_left = 0.0
	actor.switch_weapon(0)
	for frame in range(90):
		actor.render_frame(1.0 / 60.0, false, true, false)
	game.ui.sight_aiming = false
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	print("ENVIRONMENT_SPAWN_DRAW_BEGIN ms=", Time.get_ticks_msec())
	RenderingServer.force_draw(false)
	print("ENVIRONMENT_SPAWN_DRAW_END ms=", Time.get_ticks_msec())
	assert(root.get_texture().get_image().save_png(output.path_join("environment-spawn.png")) == OK)
	var record := {"name": "environment-spawn", "actor_position": [17, 0.05, 50],
		"yaw": actor.yaw, "pitch": actor.pitch, "viewport": [1280, 800], "weapon": 0, "ads": false}
	var file := FileAccess.open(output.path_join("spawn-camera-pose.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	print("ENVIRONMENT_SPAWN_REVIEW_PASS")
	quit()
