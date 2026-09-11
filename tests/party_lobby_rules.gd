extends SceneTree

class FakeGame:
	extends "res://scripts/game.gd"
	var reply := {"code": 200, "body": {}}
	var held := false
	var calls: Array = []
	var admitted_calls: Array = []
	func http_call(path: String, body: Dictionary, _internal := false, method := HTTPClient.METHOD_POST) -> Dictionary:
		calls.append([path, body, method])
		while held:
			await get_tree().process_frame
		return reply.duplicate(true)
	func connect_admission(admission: Dictionary, origin: String, bearer: String, mode: String, attempt: int) -> void:
		admitted_calls.append([admission, origin, bearer, mode, attempt])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := FakeGame.new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.token = "fake-token"
	game.token_origin = "http://test.invalid"
	game.api_url = game.token_origin
	var lobby = game.ui.party_lobby
	if "--capture-party-ui" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/party-lobby-menu.png"))
	lobby.open(game, "a")
	assert(not game.ui.menu.visible)
	assert(lobby.visible and not lobby.create_button.disabled and lobby.start_button.disabled)
	lobby.code.text = "short"
	lobby.accept_button.pressed.emit()
	assert("complete invitation" in lobby.status.text and game.calls.size() == 1)
	var party := {"id": "p", "status": "forming", "leader": "a",
		"members": [{"uid": "a", "username": "ALPHA"}], "invitation": "synthetic-invitation-for-ui-testing-only"}
	game.reply.body = party
	lobby.create_button.pressed.emit()
	assert(lobby.create_button.disabled and not lobby.copy_button.disabled and lobby.start_button.disabled)
	assert(lobby.invitation.text == party.invitation)
	party.members.append({"uid": "b", "username": "BRAVO"})
	party.erase("invitation")
	game.reply.body = party
	lobby.request("/parties/current", {}, HTTPClient.METHOD_GET)
	assert(lobby.start_button.disabled and not lobby.ready_button.disabled)
	for member in party.members:
		member.ready = true
	game.reply.body = party
	lobby.ready_button.pressed.emit()
	assert(game.calls[-1][0] == "/parties/ready" and game.calls[-1][1].ready)
	assert(not lobby.start_button.disabled and lobby.copy_button.disabled)
	assert("BRAVO" in lobby.members.text)
	party.members[0].ready = false
	game.reply.body = party
	lobby.ready_button.pressed.emit()
	assert(game.calls[-1][1].ready == false and lobby.start_button.disabled)
	party.members[0].ready = true
	game.reply.body = party
	lobby.ready_button.pressed.emit()
	assert(game.calls[-1][1].ready == true and not lobby.start_button.disabled)
	if "--capture-party-ui" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../artifacts/party-lobby.png"))
	game.reply = {"code": 503, "body": {"detail": "No room available"}}
	lobby.start_button.pressed.emit()
	assert(lobby.visible and not lobby.start_button.disabled and "No room" in lobby.status.text)
	game.reply = {"code": 200, "body": party}
	game.reply.body.admission = {"ticket": "synthetic-ticket"}
	lobby.start_button.pressed.emit()
	assert(not lobby.visible and game.admitted_calls.size() == 1)
	assert(game.admitted_calls[0][1] == "http://test.invalid" and game.admitted_calls[0][2] == "fake-token")
	assert(game.admitted_calls[0][3] == "duo")
	game.reply = {"code": 200, "body": party}
	game.reply.body.erase("admission")
	lobby.open(game, "b")
	assert(lobby.start_button.disabled and lobby.copy_button.disabled)
	game.reply.body.status = "reserved"
	game.reply.body.reservation_id = "old-group"
	lobby.request("/parties/current", {}, HTTPClient.METHOD_GET)
	assert(lobby.reset_button.visible and lobby.reset_button.disabled)
	lobby.open(game, "a")
	assert(not lobby.reset_button.disabled)
	game.reply.body.status = "forming"
	game.reply.body.erase("reservation_id")
	for member in game.reply.body.members:
		member.ready = false
	lobby.reset_button.pressed.emit()
	assert(game.calls[-1][0] == "/parties/reset" and game.calls[-1][1].group_id == "old-group")
	assert(not lobby.reset_button.visible and lobby.start_button.disabled and lobby.party.id == "p")
	var previous_calls := game.calls.size()
	lobby.return_button.pressed.emit()
	assert(not lobby.visible and game.ui.menu.visible and game.calls.size() == previous_calls)
	lobby.open(game, "b")
	game.reply = {"code": 200, "body": {}}
	lobby.back_button.pressed.emit()
	assert(not lobby.visible and game.calls[-1][2] == HTTPClient.METHOD_DELETE)
	game.held = true
	lobby.open(game, "b")
	lobby.dismiss()
	game.held = false
	await process_frame
	await process_frame
	assert(not lobby.visible and game.admitted_calls.size() == 1)
	game.reply = {"code": 401, "body": {}}
	lobby.open(game, "b")
	assert(not lobby.visible and game.token.is_empty() and game.ui.logout_button.disabled)
	game.queue_free()
	await process_frame
	print("PARTY_LOBBY_RULES_PASS invite=ok roles=ok retry=ok own_admission=ok leave=ok stale=ok expired_login=ok")
	quit()
