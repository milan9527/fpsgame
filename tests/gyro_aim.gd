extends SceneTree
const Gyro = preload("res://scripts/gyro_aim.gd")
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
func run() -> void:
	if not check(ProjectSettings.get_setting("input_devices/sensors/enable_gyroscope", false), "gyro sensor enabled in export"): return
	var sensor := Gyro.new()
	if not check(sensor.step(Vector3.ONE, 0.02, true, true) == Vector2.ZERO, "default off"): return
	sensor.mode = Gyro.Mode.ADS
	if not check(sensor.step(Vector3.ONE, 0.02, true, false) == Vector2.ZERO, "ADS gating"): return
	if not check(sensor.step(Vector3(1, 2, 3), 0.02, true, true).is_equal_approx(Vector2(0.04, 0.02)), "screen axes and radians/sec integration"): return
	sensor.mode = Gyro.Mode.ALWAYS
	for fps in [30, 60, 120]:
		sensor.reset()
		var total := Vector2.ZERO
		for frame in range(fps): total += sensor.step(Vector3(0.3, 0.6, 0), 1.0 / fps, true, false)
		if not check(total.distance_to(Vector2(0.6, 0.3)) < 0.0001, "frame-rate independence"): return
	sensor.reset()
	sensor.invert_x = true
	sensor.invert_y = true
	sensor.sensitivity = 2.0
	if not check(sensor.step(Vector3(1, 2, 0), 0.02, true, false).is_equal_approx(Vector2(-0.08, -0.04)), "independent sensitivity and inversion"): return
	if not check(sensor.step(Vector3.ONE, 0.02, false, true) == Vector2.ZERO, "inactive suppresses output"): return
	if not check(sensor.step(Vector3(0.001, -0.001, 0), 0.02, true, false) == Vector2.ZERO, "stationary noise"): return
	if not check(sensor.step(Vector3.ONE, 1.0, true, true) == Vector2.ZERO, "resume gap"): return
	if not check(sensor.step(Vector3(INF, 0, 0), 0.02, true, true) == Vector2.ZERO, "invalid readings"): return
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	var pad = game.find_child("MobileControls", true, false)
	if not check(pad != null, "mobile controls mounted"): return
	game.start_solo()
	game.set_physics_process(false)
	await process_frame
	var actor = game.actors[game.local_id]
	pad.gyro.mode = Gyro.Mode.ALWAYS
	pad.gyro.sensitivity = 1.5
	pad.save_gyro_settings()
	var reloaded := ConfigFile.new()
	reloaded.load("user://settings.cfg")
	if not check(reloaded.get_value("gyro", "mode") == 2 and is_equal_approx(reloaded.get_value("gyro", "sensitivity"), 1.5), "persist settings"): return
	var yaw: float = actor.yaw
	pad.look(Vector2(10, 0))
	var touch_yaw: float = actor.yaw
	pad.apply_gyro(Vector3(0, 1, 0), 0.02)
	if not check(not is_equal_approx(yaw, touch_yaw) and is_equal_approx(actor.yaw, touch_yaw + 0.03), "touch and gyro additive"): return
	for gated_mode in [Gyro.Mode.OFF, Gyro.Mode.ADS]:
		Input.action_release("aim")
		pad.gyro.mode = gated_mode
		pad.gyro_readings_seen = false
		yaw = actor.yaw
		pad.apply_gyro(Vector3(0, 2, 0), 0.02)
		if not check(is_equal_approx(yaw, actor.yaw) and pad.gyro_readings_seen
				and not pad.gyro.initialized, "gated mode preserves camera and sensor detection, resets smoothing"): return
		pad.gyro.mode = Gyro.Mode.ALWAYS
		pad.apply_gyro(Vector3(0, -1, 0), 0.02)
		if not check(is_equal_approx(actor.yaw, yaw - 0.03), "reactivation discards old smoothing"): return
	for blocked in ["settings", "pause", "focus", "background", "downed"]:
		if blocked == "settings": pad.show_gyro_settings(true)
		if blocked == "pause": game.ui.set_pause(true)
		if blocked == "focus": pad._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		if blocked == "background": pad._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
		if blocked == "downed": actor.downed = true
		yaw = actor.yaw
		pad.apply_gyro(Vector3(0, 2, 0), 0.02)
		if not check(is_equal_approx(yaw, actor.yaw), "camera moved while " + blocked): return
		pad.show_gyro_settings(false)
		game.ui.set_pause(false)
		pad._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
		pad._notification(MainLoop.NOTIFICATION_APPLICATION_RESUMED)
		actor.downed = false
	if DisplayServer.get_name() != "headless" and OS.has_environment("CAPTURE_ARTIFACT_DIR"):
		game.ui.set_pause(true)
		pad.show_gyro_settings(true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_ARTIFACT_DIR").path_join("gyro-settings.png"))
	print("GYRO_AIM_PASS axes=ok modes=ok fps=ok noise=ok focus=ok modal=ok touch=ok persistence=ok")
	game.queue_free()
	await process_frame
	quit()
