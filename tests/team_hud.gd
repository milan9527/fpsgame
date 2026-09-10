extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("duo")
	game.elapsed = 10
	var ally = game.actors[-1]
	game._process(0.016)
	assert(game.ui.team_label.visible and ally.display_name in game.ui.team_label.text)
	assert(game.ui.team_markers.size() == 1 and game.ui.team_markers[0].id == -1)
	assert(game.ui.tactical_map.teammates.size() == 1)
	assert("100 HP" in game.ui.team_label.text)
	ally.position += Vector3(12, 0, 0)
	game._process(0.016)
	assert(game.ui.tactical_map.teammates[0].position == ally.position)
	game.damage(ally, 10000, -2, true)
	game._process(0.016)
	assert(ally.downed and "DOWNED" in game.ui.team_label.text)
	assert(game.ui.team_markers[0].downed)
	if "--capture-team" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/team-hud.png") == OK)
		game.ui.set_map(true)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/team-map.png") == OK)
		game.ui.set_map(false)
	game.damage(ally, 10000, -2, true)
	game._process(0.016)
	assert("ELIMINATED" in game.ui.team_label.text and not game.ui.team_markers[0].alive)
	game.actors.erase(-1)
	ally.queue_free()
	game._process(0.016)
	assert(game.ui.team_markers.is_empty() and game.ui.tactical_map.teammates.is_empty())
	assert("UNAVAILABLE" in game.ui.team_label.text)
	game.start_solo()
	game._process(0.016)
	assert(not game.ui.team_label.visible and game.ui.team_markers.is_empty())
	assert(game.ui.tactical_map.teammates.is_empty(), "New solo rounds cannot retain old team positions")
	game.leave()
	assert(game.ui.team_markers.is_empty())
	print("TEAM_HUD_PASS teammate_only=ok health=ok movement=ok downed=ok eliminated=ok unavailable=ok map=ok reset=ok")
	game.request_quit()
