extends SceneTree

var submitted := []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var ui = game.ui
	# Remove the application's connection handlers so validation never sends HTTP.
	for connection in ui.online_requested.get_connections():
		ui.online_requested.disconnect(connection.callable)
	ui.online_requested.connect(func(name, secret, register, address): submitted.append([name, secret.length(), register, address]))
	ui.username.text = "ab"
	ui.password.text = "local-test-password"
	ui.endpoint.text = "https://example.invalid"
	ui.online(false)
	assert(submitted.is_empty() and not ui.busy and "username" in ui.status.text)
	ui.username.text = "local_player"
	ui.password.text = "short"
	ui.online(true)
	assert(submitted.is_empty() and not ui.busy and "password" in ui.status.text)
	ui.password.text = "local-test-password"
	for address in ["", "example.invalid", "ftp://example.invalid", "https://", "https://name:secret@example.invalid", "https://example.invalid?x=y", "https://example.invalid/#part"]:
		ui.endpoint.text = address
		ui.online(false)
		assert(submitted.is_empty() and not ui.busy and "server address" in ui.status.text)
	for address in ["https://example.invalid", "http://127.0.0.1:8000", "http://[::1]:8000", "https://example.invalid/api"]:
		ui.busy = false
		ui.username.text = " local_player "
		ui.endpoint.text = " " + address + "/ "
		ui.online(false)
		assert(ui.busy and submitted[-1] == ["local_player", 19, false, address])
		var count := submitted.size()
		ui.online(false)
		assert(submitted.size() == count, "Busy form must not submit twice")
	print("LOGIN_FORM_PASS local_errors=ok no_requests=ok normalized_endpoint=ok ipv6=ok base_path=ok duplicate_submit=blocked")
	game.request_quit()
