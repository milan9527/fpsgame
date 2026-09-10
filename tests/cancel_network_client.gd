extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 15000
	while game.admission_ticket.is_empty():
		assert(Time.get_ticks_msec() < deadline, "No reservation allocated")
		await process_frame
	game.bot_client = false
	assert(not game.running and game.ui.busy and not game.ui.connection_cancel.disabled)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../artifacts/cancel-connection.png")
	var started := Time.get_ticks_msec()
	game.ui.connection_cancel.pressed.emit()
	assert(not game.online and game.ui.menu.visible and game.ui.connection_cancel.disabled)
	var payload: Dictionary = game.build_info.duplicate()
	payload.room_id = OS.get_environment("TEST_ROOM_ID")
	var response := {}
	for attempt in range(4):
		await create_timer(0.5).timeout
		response = await game.http_call("/matchmaking/rooms/join", payload)
		if response.code == 200:
			break
	assert(response.code == 200, "Cancelled reservation still blocked a fresh allocation")
	assert(Time.get_ticks_msec() - started < 6000)
	await game.cancel_ticket(response.body.ticket, game.api_url, game.token)
	print("CANCEL_NETWORK_CLIENT_PASS real_account=ok unused_lease_released=ok immediate_reallocation=ok menu=ok")
	game.request_quit()
