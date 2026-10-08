extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value

func touch(pad, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	pad._input(event)

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	await process_frame
	var pad = game.find_child("MobileControls", true, false)
	if not check(pad != null, "Mobile controls must be mounted"):
		return
	on_request_permissions_result.emit(pad.MICROPHONE_PERMISSION, true)
	if not check(pad.microphone_permission_granted and not pad.voice_requested,
			"Permission callbacks must update permission without enabling voice"):
		return
	on_request_permissions_result.emit("android.permission.CAMERA", false)
	if not check(pad.microphone_permission_granted, "Other permissions must not disable microphone"):
		return
	on_request_permissions_result.emit(pad.MICROPHONE_PERMISSION, false)
	if not check(not pad.microphone_permission_granted, "Microphone denial must invalidate permission"):
		return
	pad._notification(NOTIFICATION_APPLICATION_RESUMED)
	if not check(pad.microphone_permission_granted == (not OS.has_feature("android")
			or pad.MICROPHONE_PERMISSION in OS.get_granted_permissions()),
			"Resume must refresh permission after a settings change"):
		return
	game.start_solo()
	await process_frame
	await process_frame
	var actor = game.actors[game.local_id]
	var start_yaw: float = actor.yaw
	touch(pad, 0, pad.stick_center + Vector2(0, -80), true)
	if not check(not Input.emulate_mouse_from_touch and not Input.is_action_pressed("fire"),
			"The movement stick must not emulate a mouse click and fire"):
		return
	touch(pad, 1, pad.buttons.fire[0].get_center(), true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = pad.buttons.fire[0].get_center()
	drag.relative = Vector2(55, 15)
	pad._input(drag)
	if not check(Input.is_action_pressed("forward") and Input.is_action_pressed("fire")
			and actor.yaw != start_yaw, "Two fingers must move, fire and aim together"):
		return
	touch(pad, 2, pad.buttons.aim[0].get_center(), true)
	touch(pad, 2, pad.buttons.aim[0].get_center(), false)
	if not check(Input.is_action_pressed("aim"), "Aim toggle must survive finger release"):
		return
	touch(pad, 1, Vector2.ZERO, false)
	if not check(not Input.is_action_pressed("fire") and Input.is_action_pressed("forward"),
			"Releasing fire must preserve the other finger's movement"):
		return
	pad._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if not check(not Input.is_action_pressed("forward") and not Input.is_action_pressed("aim")
			and pad.fingers.is_empty(), "Focus loss must release all touch inputs"):
		return
	touch(pad, 0, pad.buttons.pause[0].get_center(), true)
	await process_frame
	if not check(game.ui.pause_panel.visible and paused, "Mobile offline menu must pause the game"):
		return
	if not check(pad.pause_panel.visible and pad.save_button.visible and Input.emulate_mouse_from_touch,
			"Opening the pause menu must refresh save eligibility and restore GUI touch input"):
		return
	game.ui.set_pause(false)
	await process_frame
	touch(pad, 0, pad.buttons.inventory[0].get_center(), true)
	await process_frame
	if not check(game.ui.inventory.visible, "Mobile inventory must open"):
		return
	touch(pad, 0, pad.buttons.pause[0].get_center(), true)
	await process_frame
	if not check(not game.ui.inventory.visible, "Mobile back button must close inventory"):
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_ARTIFACT_DIR") + "/mobile-controls.png")
	print("MOBILE_CONTROLS_PASS permissions=ok multitouch=ok aim=ok release=ok focus=ok pause=ok inventory=ok")
	game.request_quit()
