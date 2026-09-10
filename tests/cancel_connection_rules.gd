extends SceneTree

class DelayedGame:
	extends "res://scripts/game.gd"
	var held := false
	var release := false
	var cancelled := []

	func http_call(path: String, _body: Dictionary, _internal := false, _method := HTTPClient.METHOD_POST) -> Dictionary:
		if path == "/protocol":
			return {"code": 200, "body": build_info.duplicate()}
		if path == "/auth/login":
			return {"code": 200, "body": {"token": "test-token"}}
		if path == "/matchmaking/rooms/join":
			held = true
			while not release:
				await get_tree().process_frame
			return {"code": 200, "body": {"ticket": "unused-test-ticket-123456789", "room_id": "test-room", "host": "127.0.0.1", "port": 27999, "build": build_info.duplicate()}}
		return {"code": 500, "body": {}}

	func cancel_ticket(value: String, origin: String, bearer: String) -> void:
		cancelled.append([value, origin, bearer])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := DelayedGame.new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.sign_in("tester", "unused-test-password", false, "http://first.invalid")
	while not game.held:
		await process_frame
	assert(game.ui.busy and not game.ui.connection_cancel.disabled)
	game.ui.connection_cancel.pressed.emit()
	assert(not game.ui.busy and game.ui.connection_cancel.disabled)
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.release = true
	await process_frame
	await process_frame
	assert(not game.online and game.running and game.phase == "live")
	assert(game.cancelled.has(["unused-test-ticket-123456789", "http://first.invalid", "test-token"]), "Late response cancelled with its original auth origin")
	assert(game.admission_ticket.is_empty())
	game.queue_free()
	await process_frame
	print("CANCEL_CONNECTION_RULES_PASS button=ok stale_response=ok original_auth_origin=ok solo_not_replaced=ok")
	quit()
