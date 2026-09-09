extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	assert(game.build_info.protocol == 2)
	assert(game.compatible_build(game.build_info))
	assert(not game.compatible_build({"protocol": 2, "content_revision": "wrong"}))
	game.build_info.protocol += 1
	# These credentials must never be needed: preflight rejects before account login.
	await game.sign_in("unused_account", "unused-password", false, "http://127.0.0.1:8000")
	assert(not game.online and not game.running, "No ENet connection is created on mismatch")
	assert("version mismatch" in game.ui.status.text, "UI gives actionable mismatch message")
	assert(game.token == "", "Mismatch rejected before authentication")
	print("PROTOCOL_CLIENT_PASS mismatch=visible no_connection=ok no_login=ok")
	quit()
