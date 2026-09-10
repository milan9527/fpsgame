extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 45000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	while game.phase != "live":
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	print("SESSION_LIVE_READY")
	while game.running:
		assert(Time.get_ticks_msec() < deadline, "Revoked ENet session remained connected")
		await process_frame
	assert(game.token.is_empty() and "Account signed out" in game.ui.status.text)
	print("SESSION_REVOKED_NETWORK_PASS notification=ok disconnected=ok local_token_cleared=ok")
	game.request_quit()
