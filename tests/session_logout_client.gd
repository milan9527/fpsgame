extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	var response: Dictionary = await game.http_call("/auth/login", {"username": OS.get_environment("TEST_USERNAME"), "password": OS.get_environment("TEST_PASSWORD")})
	assert(response.code == 200)
	game.token = response.body.token
	game.token_origin = game.api_url
	game.ui.logout_button.disabled = false
	assert(await game.sign_out_all())
	assert(game.token.is_empty() and game.ui.logout_button.disabled and game.ui.password.text.is_empty())
	assert("Signed out of all devices" in game.ui.status.text)
	if OS.has_environment("CAPTURE_PATH"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	game.token = "synthetic-invalid-token"
	game.token_origin = game.api_url
	assert(not await game.sign_out_all())
	assert(game.token.is_empty() and "This login expired" in game.ui.status.text)
	game.token = "synthetic-unconfirmed-token"
	game.token_origin = "http://127.0.0.1:1"
	assert(not await game.sign_out_all())
	assert(game.token == "synthetic-unconfirmed-token" and not game.ui.logout_button.disabled)
	print("SESSION_LOGOUT_UI_PASS success=ok expired_not_false_success=ok failed_request_preserves_retry=ok")
	game.request_quit()
