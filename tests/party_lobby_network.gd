extends SceneTree

var deadline := 0
func _initialize() -> void:
	call_deferred("run")

func wait_until(predicate: Callable) -> void:
	while not predicate.call():
		assert(Time.get_ticks_msec() < deadline, "Party UI network timeout")
		await process_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	deadline = Time.get_ticks_msec() + 55000
	game.ui.username.text = OS.get_environment("TEST_USERNAME")
	game.ui.password.text = OS.get_environment("TEST_PASSWORD")
	var endpoint := OS.get_environment("API_URL")
	game.ui.endpoint.text = endpoint if not endpoint.is_empty() else "http://127.0.0.1:8001"
	game.ui.online_mode.select(1)
	game.ui.online(false)
	var lobby = game.ui.party_lobby
	await wait_until(func(): return lobby.visible and not lobby.busy and lobby.known)
	assert(game.api_url == game.ui.endpoint.text, "Fixture must connect to the selected deployment")
	assert(game.ui.password.text.is_empty())
	var path := OS.get_environment("PARTY_TEST_INVITATION_FILE")
	var leader := OS.get_environment("PARTY_TEST_ROLE") == "leader"
	var requeue := OS.get_environment("PARTY_TEST_REQUEUE") == "1"
	if requeue:
		assert(lobby.party.id == FileAccess.get_file_as_string(path + ".party"))
		if leader:
			for attempt in range(10):
				lobby.reset_button.pressed.emit()
				await wait_until(func(): return not lobby.busy)
				if lobby.party.get("status", "") == "forming":
					break
				await create_timer(1).timeout
	else:
		assert(not lobby.create_button.disabled)
		if leader:
			lobby.create_button.pressed.emit()
			await wait_until(func(): return not lobby.busy and not lobby.invitation.text.is_empty())
			var file := FileAccess.open(path, FileAccess.WRITE)
			assert(file != null)
			file.store_string(lobby.invitation.text)
			file.close()
			file = FileAccess.open(path + ".party", FileAccess.WRITE)
			file.store_string(lobby.party.id)
			file.close()
		else:
			await wait_until(func(): return FileAccess.file_exists(path))
			lobby.code.text = FileAccess.get_file_as_string(path)
			lobby.accept_button.pressed.emit()
	await wait_until(func(): return not lobby.busy and lobby.party.get("status", "") == "forming" and lobby.party.get("members", []).size() == 2)
	assert(not lobby.own_ready())
	lobby.ready_button.pressed.emit()
	if leader:
		await wait_until(func(): return not lobby.start_button.disabled)
		lobby.start_button.pressed.emit()
	await wait_until(func(): return game.running and game.phase == "live")
	assert(not lobby.visible and game.match_mode == "duo")
	assert(game.actors.has(game.local_id))
	var local_actor = game.actors[game.local_id]
	var ally_found := false
	for actor in game.actors.values():
		if actor.actor_id != game.local_id and actor.team_id == local_actor.team_id:
			assert(actor.display_name == OS.get_environment("PARTY_TEST_ALLY"))
			ally_found = true
	assert(ally_found)
	if requeue:
		assert(game.network_round_id != FileAccess.get_file_as_string(path + ".round"))
		print("PARTY_REQUEUE_CLIENT_PASS same_party=ok new_round=ok readiness_reset=ok")
	elif leader:
		var file := FileAccess.open(path + ".round", FileAccess.WRITE)
		file.store_string(game.network_round_id)
		file.close()
	print("PARTY_LOBBY_NETWORK_PASS login_ui=ok invitation_controls=ok admission=ok same_team=ok")
	await create_timer(1).timeout
	game.request_quit()
