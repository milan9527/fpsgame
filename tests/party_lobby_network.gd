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
	game.ui.endpoint.text = "http://127.0.0.1:8001"
	game.ui.online_mode.select(1)
	game.ui.online(false)
	var lobby = game.ui.party_lobby
	await wait_until(func(): return lobby.visible and not lobby.busy and lobby.known)
	assert(game.ui.password.text.is_empty() and not lobby.create_button.disabled)
	var path := OS.get_environment("PARTY_TEST_INVITATION_FILE")
	if OS.get_environment("PARTY_TEST_ROLE") == "leader":
		lobby.create_button.pressed.emit()
		await wait_until(func(): return not lobby.busy and not lobby.invitation.text.is_empty())
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert(file != null)
		file.store_string(lobby.invitation.text)
		file.close()
		await wait_until(func(): return not lobby.start_button.disabled)
		assert(lobby.party.members.size() == 2)
		lobby.start_button.pressed.emit()
	else:
		await wait_until(func(): return FileAccess.file_exists(path))
		lobby.code.text = FileAccess.get_file_as_string(path)
		lobby.accept_button.pressed.emit()
		await wait_until(func(): return not lobby.visible or (not lobby.busy and not lobby.party.is_empty()))
		if lobby.visible:
			assert(lobby.start_button.disabled and lobby.invitation.text.is_empty())
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
	print("PARTY_LOBBY_NETWORK_PASS login_ui=ok invitation_controls=ok admission=ok same_team=ok")
	await create_timer(1).timeout
	game.request_quit()
