extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	await process_frame
	var pad = game.find_child("MobileControls", true, false)
	var server := "https://memory-test.invalid/api"
	game.ui.endpoint.text = server
	pad.endpoint.text = server
	game.ui.remember_login(server, "remember_test", "synthetic-password-123")
	game.ui.show_game()
	await process_frame
	game.ui.show_menu()
	await process_frame
	if game.ui.username.text != "remember_test" or game.ui.password.text != "synthetic-password-123" or pad.password.text != "synthetic-password-123":
		push_error("Saved login not restored in desktop/mobile menu")
		quit(1)
		return
	pad.endpoint.text = "https://other-server.invalid/api"
	pad.endpoint.text_changed.emit(pad.endpoint.text)
	if pad.password.text != "":
		push_error("Credential leaked to another endpoint")
		quit(1)
		return
	pad.endpoint.text = server
	game.ui.forget_login()
	pad.restore_login()
	if pad.password.text != "" or game.ui.password.text != "":
		push_error("Forget did not clear credentials")
		quit(1)
		return
	print("LOGIN_MEMORY_UI_PASS")
	quit()
