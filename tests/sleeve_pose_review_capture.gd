extends SceneTree

func wants_capture(label: String) -> bool:
	var requested := OS.get_environment("REVIEW_POSES")
	return requested.is_empty() or label in requested.split(",")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	RenderingServer.render_loop_enabled = false
	var initial_position: Vector3 = game.actors[game.local_id].position
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	actor.reload_left = 0.0
	actor.switch_weapon(0)
	for frame in range(180):
		await physics_frame
		for participant in game.actors.values():
			participant.simulate(1.0 / 60.0)
			participant.render_frame(1.0 / 60.0, false, participant == actor, false)
	game.ui.sight_aiming = false
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	if wants_capture("default-spawn"):
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output.path_join("default-spawn.png")) == OK)
	var record := {"name": "default-spawn", "actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"initial_position": [initial_position.x, initial_position.y, initial_position.z],
		"camera_position": [root.get_camera_3d().global_position.x, root.get_camera_3d().global_position.y, root.get_camera_3d().global_position.z],
		"yaw": actor.yaw, "pitch": actor.pitch, "viewport": [1280, 800], "weapon": 0, "ads": false}
	var file := FileAccess.open(output.path_join("spawn-camera-pose.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	var poses := [record] if wants_capture("default-spawn") else []
	actor.aiming = true
	await advance_pose(actor, 36)
	await save_pose(game, actor, output, "ads", poses)
	game.shoot(actor)
	actor.aiming = false
	await advance_pose(actor, 24)
	actor.reload_weapon()
	assert(actor.reload_left > 0.0)
	await advance_pose(actor, int(actor.RELOAD[0] * 30))
	await save_pose(game, actor, output, "reload-middle", poses)
	await advance_pose(actor, int(actor.RELOAD[0] * 30) + 15)
	assert(actor.reload_left <= 0.0 and actor.ammo == actor.CAPACITY[0])
	await save_pose(game, actor, output, "reload-complete", poses)
	var audit := FileAccess.open(output.path_join("sleeve-pose-review.json"), FileAccess.WRITE)
	audit.store_string(JSON.stringify({"passed": true, "poses": poses,
		"capture_filter": OS.get_environment("REVIEW_POSES"),
		"scope": "carbine default spawn, ADS, reload middle and completion simulated; only listed poses rendered; not full weapon/third-person coverage"}, "\t"))
	audit.close()
	print("SLEEVE_POSE_REVIEW_PASS reload_refilled=true")
	quit()

func advance_pose(actor, frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		actor.simulate(1.0 / 60.0)
		actor.render_frame(1.0 / 60.0, false, true, actor.aiming)

func save_pose(game, actor, output: String, label: String, poses: Array) -> void:
	if not wants_capture(label):
		return
	print("SLEEVE_CAPTURE_BEGIN label=", label, " wall_ms=", Time.get_ticks_msec())
	game.ui.sight_aiming = actor.aiming
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	for frame in range(4): await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	var cam := root.get_camera_3d()
	poses.append({"name": label, "actor_position": [actor.position.x, actor.position.y, actor.position.z],
		"camera_position": [cam.global_position.x, cam.global_position.y, cam.global_position.z],
		"camera_rotation": [cam.global_rotation.x, cam.global_rotation.y, cam.global_rotation.z],
		"yaw": actor.yaw, "pitch": actor.pitch, "ads": actor.aiming, "reload_left": actor.reload_left, "ammo": actor.ammo})
	var partial := FileAccess.open(output.path_join("poses-partial.json"), FileAccess.WRITE)
	partial.store_string(JSON.stringify({"passed": false, "poses": poses}, "\t"))
	partial.close()
