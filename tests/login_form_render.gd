extends SceneTree

var submitted := 0

func _initialize() -> void:
	call_deferred("run")

func press_enter() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	var ui = game.ui
	for connection in ui.online_requested.get_connections():
		ui.online_requested.disconnect(connection.callable)
	ui.online_requested.connect(func(_name, _password, _register, _address): submitted += 1)
	for dimensions in [Vector2i(1280, 800), Vector2i(960, 600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var bounds: Rect2 = ui.menu.get_viewport_rect()
		assert(bounds.encloses(ui.status.get_global_rect()), "Login status must remain inside the viewport")
		assert(bounds.encloses(ui.endpoint.get_global_rect()))
		assert(ui.status.get_line_count() * ui.status.get_line_height() <= ui.status.size.y)
		await RenderingServer.frame_post_draw
		var output := OS.get_environment("CAPTURE_ARTIFACT_DIR").path_join("login-%dx%d.png" % [dimensions.x, dimensions.y])
		assert(root.get_texture().get_image().save_png(output) == OK)
	ui.username.text = "test_player"
	ui.password.text = ""
	ui.username.grab_focus()
	await press_enter()
	assert(ui.password.has_focus() and submitted == 0)
	await press_enter()
	assert(submitted == 0 and not ui.busy and "password" in ui.status.text)
	ui.password.text = "local-test-password"
	ui.endpoint.text = "https://example.invalid"
	await press_enter()
	assert(submitted == 1 and ui.busy)
	await press_enter()
	assert(submitted == 1)
	print("LOGIN_FORM_RENDER_PASS sizes=1280x800,960x600 status_visible=ok keyboard_focus=ok enter_signin=ok invalid_blocked=ok busy_blocked=ok")
	game.request_quit()
