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
	while not game.running or game.phase != "live" or game.network_status.last_snapshot < 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	await create_timer(2).timeout
	assert(game.ui.network_label.visible and game.network_status.rtt >= 100)
	assert(not game.network_status.describe(Time.get_ticks_msec()).stalled)
	print("NETWORK_MONITOR_READY phase=live rtt_ms=", game.network_status.rtt)
	while not game.network_status.describe(Time.get_ticks_msec()).stalled:
		assert(Time.get_ticks_msec() < deadline and game.running)
		await process_frame
	await process_frame
	assert("SERVER UPDATES DELAYED" in game.ui.network_label.text)
	print("NETWORK_MONITOR_STALLED")
	if OS.has_environment("CAPTURE_PATH"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	while game.network_status.describe(Time.get_ticks_msec()).stalled:
		assert(Time.get_ticks_msec() < deadline and game.running)
		await process_frame
	await create_timer(0.5).timeout
	assert(game.running and "SERVER UPDATES DELAYED" not in game.ui.network_label.text)
	assert(Time.get_ticks_msec() - game.network_status.last_snapshot < 500)
	print("NETWORK_MONITOR_REAL_PROXY_PASS rtt=measured stall=detected recovery=ok connected=true")
	game.request_quit()
