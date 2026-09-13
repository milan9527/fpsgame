extends SceneTree

class LoginGame:
	extends "res://scripts/game.gd"
	var responses := []
	var calls := []
	func http_call(path: String, body: Dictionary, internal := false, method := HTTPClient.METHOD_POST) -> Dictionary:
		calls.append(path)
		return responses.pop_front()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = LoginGame.new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	for failure in [0, 404, 503, 401, 409]:
		game.calls.clear()
		game.responses = [{"code": failure, "body": {"detail": "Unavailable"}}]
		if failure in [401, 409]:
			game.responses.push_front({"code": 200, "body": game.build_info.duplicate()})
		game.ui.username.text = "retry_player"
		game.ui.endpoint.text = "https://example.invalid"
		game.ui.password.text = "temporary-test-password"
		game.ui.username.grab_focus()
		await game.sign_in(game.ui.username.text, game.ui.password.text, failure == 409, game.ui.endpoint.text)
		assert(game.ui.menu.visible and not game.ui.busy and game.ui.connection_cancel.disabled)
		assert(game.ui.username.text == "retry_player" and game.ui.endpoint.text == "https://example.invalid")
		assert(game.ui.password.text.is_empty(), "Failed requests must preserve password clearing")
		if failure == 401:
			assert(game.ui.password.has_focus() and game.calls == ["/protocol", "/auth/login"])
		elif failure == 409:
			assert(game.ui.username.has_focus() and game.calls == ["/protocol", "/auth/register"])
		else:
			assert(game.ui.endpoint.has_focus() and game.calls == ["/protocol"])
		assert(game.token.is_empty() and not game.running)
	print("LOGIN_RETRY_PASS unavailable=address_focus legacy_server=address_focus auth_failure=password_focus name_conflict=username_focus identity_preserved=ok password_cleared=ok idle=ok")
	game.request_quit()
