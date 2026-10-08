extends SceneTree
## Rendering regression only: run with Xvfb/OpenGL, never FPS acceptance.

class Actor extends RefCounted:
	var alive := true
	var yaw := 0.0
	var pitch := 0.0
	func is_seated() -> bool:
		return false

var draws := 0
var pad

func _initialize() -> void:
	call_deferred("run")

func settled() -> void:
	for i in 3:
		await process_frame
		await RenderingServer.frame_post_draw

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	pad._input(event)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = Vector2(12, 3)
	pad._input(event)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Requires a rendering display")
		quit(1)
		return
	var actor := Actor.new()
	for action in ["fire", "aim", "left", "right", "forward", "back"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var hidden := Control.new()
	hidden.visible = false
	pad = load("res://scripts/mobile_controls.gd").new()
	pad.game = {
		"running": true, "local_id": 1, "actors": {1: actor},
		"ui": {"menu": hidden, "pause_panel": hidden, "inventory": hidden,
			"tactical_map": hidden, "controls": hidden, "sensitivity": 0.002}
	}
	pad.size = Vector2(1440, 900)
	pad.stick_center = Vector2(180, 650)
	pad.buttons = {"fire": [Rect2(1250, 560, 150, 150), "FIRE"]}
	root.add_child(pad)
	pad.set_process(false)
	pad.draw.connect(func(): draws += 1)
	await settled()
	var idle_draws := draws
	touch(0, Vector2(800, 400), true)
	await settled()
	assert(draws == idle_draws, "Look press must retain overlay drawing")
	var baseline := draws
	var yaw := actor.yaw
	for i in 12:
		drag(0, Vector2(812, 403))
		await settled()
	assert(draws == baseline and actor.yaw != yaw, "Look must orbit without overlay redraw")
	touch(1, Vector2(1330, 660), true)
	await settled()
	assert(draws > baseline and Input.is_action_pressed("fire"), "Press must redraw and fire")
	baseline = draws
	yaw = actor.yaw
	for i in 12:
		drag(1, Vector2(1335, 665))
		await settled()
	assert(draws == baseline and actor.yaw != yaw and Input.is_action_pressed("fire"),
		"Fire drag must keep shooting and orbit without overlay redraw")
	touch(2, Vector2(180, 570), true)
	await settled()
	baseline = draws
	drag(2, Vector2(250, 650))
	await settled()
	assert(draws > baseline and Input.is_action_pressed("right"), "Stick drag must redraw and move")
	baseline = draws
	var right_strength := Input.get_action_strength("right")
	for i in 12:
		drag(2, Vector2(250, 650))
		await settled()
	assert(draws == baseline and Input.get_action_strength("right") == right_strength,
		"Unchanged stick must retain drawing and movement strength")
	drag(2, Vector2(110, 580))
	await settled()
	assert(is_equal_approx(Input.get_action_strength("left"), 70.0 / 105.0)
		and is_equal_approx(Input.get_action_strength("forward"), 70.0 / 105.0)
		and Input.get_action_strength("right") == 0.0
		and Input.get_action_strength("back") == 0.0,
		"Direction reversal must replace all prior strengths")
	assert(not Input.is_action_pressed("right") and not Input.is_action_pressed("back"),
		"Zero-strength directions must be released, not pressed at zero")
	drag(2, pad.stick_center)
	await settled()
	assert(draws > baseline and not Input.is_action_pressed("right")
		and not Input.is_action_pressed("left") and not Input.is_action_pressed("forward"),
		"Returning stick to center must redraw and stop")
	drag(2, Vector2(250, 650))
	await settled()
	baseline = draws
	touch(0, Vector2.ZERO, false)
	await settled()
	assert(draws == baseline and Input.is_action_pressed("fire")
		and Input.is_action_pressed("right"),
		"Look release must retain drawing and other fingers' actions")
	baseline = draws
	touch(1, Vector2.ZERO, false)
	await settled()
	assert(draws > baseline and not Input.is_action_pressed("fire")
		and Input.is_action_pressed("right"), "Release must redraw without cancelling other finger")
	pad.release_all()
	pad.game = null
	pad.queue_free()
	hidden.free()
	print("MOBILE_CONTROLS_REDRAW_PASS look_drags=12 fire_drags=12 drag_redraws=0 look_press_release_redraws=0 stick=ok release=ok")
	quit()
