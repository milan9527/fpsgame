extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	await game.sign_in("validation_probe", "secret7", false, "http://127.0.0.1:8000")
	assert(game.ui.menu.visible and not game.running)
	assert("Password must contain" in game.ui.status.text)
	assert(not "secret7" in game.ui.status.text)
	assert(not "input" in game.ui.status.text)
	if OS.has_environment("CAPTURE_PATH"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	print("VALIDATION_MESSAGE_PASS live_api=ok friendly_guidance=ok no_password_echo=ok")
	game.request_quit()
