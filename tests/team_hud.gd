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
	Input.action_press("scoreboard")
	game._process(0.016)
	assert(game.ui.scoreboard_panel.visible and "RANGER" in game.ui.scoreboard_label.text)
	Input.action_release("scoreboard")
	game._process(0.016)
	assert(not game.ui.scoreboard_panel.visible)
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
	# A downed actor must submit only the final health, including repeated frames.
	var health_changes := [0]
	var track_health = func(_value): health_changes[0] += 1
	game.ui.health_bar.value_changed.connect(track_health)
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, [], "")
	assert(game.ui.health_bar.value == ally.down_health)
	health_changes[0] = 0
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, [], "")
	assert(health_changes[0] == 0, "Unchanged downed health must not emit intermediate values")
	ally.down_health -= 1
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, [], "")
	assert(health_changes[0] == 1 and game.ui.health_bar.value == ally.down_health)
	ally.down_health += 1
	game.ui.health_bar.value_changed.disconnect(track_health)
	# HUD caches must follow rendered second/metre boundaries and phase changes.
	var circle := {"stage": 2, "moving": false, "remaining": 10.2}
	game.ui.update_hud(ally, 2, "live", 60.9, 100.9, [], "", circle)
	var first_stats: String = game.ui.stats.text
	var first_headline: String = game.ui.headline.text
	assert("01:00" in first_stats and "ZONE 100m" in first_stats)
	assert("ZONE 2 · CLOSES IN 11s" in first_headline)
	circle.remaining = 10.1
	game.ui.update_hud(ally, 2, "live", 60.1, 100.1, [], "", circle)
	assert(game.ui.stats.text == first_stats and game.ui.headline.text == first_headline)
	circle.remaining = 10.0
	circle.moving = true
	circle.stage = 3
	game.ui.update_hud(ally, 1, "live", 59.9, 99.9, [], "", circle)
	assert("01 ALIVE" in game.ui.stats.text and "00:59" in game.ui.stats.text and "ZONE 99m" in game.ui.stats.text)
	assert("ZONE 3 · SHRINKING 10s" in game.ui.headline.text)
	game.ui.update_hud(ally, 2, "waiting", 60.0, 100.0, [], "", circle)
	assert(game.ui.headline.text == "ASH VALLEY   /   WAITING")
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, [], "")
	assert(game.ui.headline.text == "ASH VALLEY   /   LIVE" and game.ui.stats.text == first_stats)
	# Event producers append, replace and clear the same array instance.
	var hud_events: Array = ["FIRST"]
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, hud_events, "")
	assert(game.ui.feed.text == "FIRST")
	hud_events.append("SECOND")
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, hud_events, "")
	assert(game.ui.feed.text == "FIRST\nSECOND")
	hud_events[0] = "REPLACED"
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, hud_events, "")
	assert(game.ui.feed.text == "REPLACED\nSECOND")
	hud_events.clear()
	game.ui.update_hud(ally, 2, "live", 60.0, 100.0, hud_events, "")
	assert(game.ui.feed.text == "")
	game._process(0.016)
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
