extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null # This fixture must not modify the player's local results.
	await process_frame
	await game.show_leaderboard("http://127.0.0.1:8000")
	assert(game.ui.leaderboard_panel.visible, "Leaderboard opens from the real service")
	assert("RANK" in game.ui.leaderboard_label.text, "Leaderboard renders rows")
	game.ui.leaderboard_panel.visible = false
	game.start_solo()
	game.ui.update_scoreboard(game.actors.values(), true)
	assert("RANGER" in game.ui.scoreboard_label.text, "Scoreboard renders full roster")
	game.leave()
	assert(game.ui.menu.visible and not game.ui.hud.visible, "Return to menu resets UI")
	print("UI_FLOW_PASS leaderboard=ok scoreboard=ok leave=ok")
	quit()
