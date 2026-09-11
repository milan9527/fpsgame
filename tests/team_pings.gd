extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("duo")
	var rules = game.team_pings
	var actors: Dictionary = game.actors
	var teams = game.teams
	assert(not rules.submit(1, 1, Vector2(INF, 0), false, 0, actors, teams))
	assert(not rules.submit(1, 1, Vector2(116, 0), false, 0, actors, teams))
	assert(not rules.submit(1, 65, Vector2.ZERO, false, 0, actors, teams))
	assert(rules.submit(1, 1, Vector2(20, 30), false, 0, actors, teams))
	assert(rules.visible_for(-1, 0, actors, teams).size() == 1)
	assert(rules.visible_for(-2, 0, actors, teams).is_empty())
	assert(not rules.submit(1, 1, Vector2.ZERO, false, 1, actors, teams))
	assert(not rules.submit(1, 2, Vector2.ZERO, false, 0.5, actors, teams))
	assert(rules.submit(1, 3, Vector2.ZERO, true, 0.5, actors, teams))
	assert(rules.visible_for(-1, 0.5, actors, teams).is_empty())
	assert(not rules.submit(1, 4, Vector2.ONE, false, 0.6, actors, teams))
	assert(rules.submit(1, 5, Vector2.ONE, false, 1, actors, teams))
	assert(rules.visible_for(-1, 21, actors, teams).is_empty())
	assert(rules.submit(1, 6, Vector2.ONE, false, 22, actors, teams))
	actors[1].alive = false
	assert(not rules.submit(1, 7, Vector2.ZERO, false, 23, actors, teams))
	assert(rules.visible_for(-1, 23, actors, teams).is_empty())
	actors[1].alive = true
	rules.reset()
	game.elapsed = 10
	var map = game.ui.tactical_map
	var click := InputEventMouseButton.new()
	click.position = map.world_to_map(Vector2(12, 18))
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map._gui_input(click)
	assert(map.shared_pings.size() == 1 and map.shared_pings[0].point.is_equal_approx(Vector2(12, 18)))
	game._process(0.016)
	assert("PING" in game.ui.team_ping_label.text)
	if "--capture-team-pings" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/team-pings-hud.png") == OK)
		game.ui.set_map(true)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/team-pings-map.png") == OK)
		game.ui.set_map(false)
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	assert(map.shared_pings.is_empty() and map.waypoint == null)
	game.online = true
	game.ui.set_pause(false)
	game.network_round_id = "current"
	game.team_ping_snapshot("stale", [{"id": 1, "point": Vector2.ZERO, "name": "TEST", "remaining": 20.0}])
	assert(map.shared_pings.is_empty())
	game.team_ping_snapshot("current", [{"id": 1, "point": Vector2.ZERO, "name": "TEST", "remaining": 0.001}])
	assert(map.shared_pings.size() == 1)
	await create_timer(0.02).timeout
	game._process(0.016)
	assert(map.shared_pings.is_empty() and game.ui.team_ping_label.text.is_empty())
	game.online = false
	game.start_solo()
	assert(rules.markers.is_empty() and game.team_ping_sequence == 0)
	assert(not rules.submit(1, 1, Vector2.ZERO, false, 0, game.actors, game.teams))
	game.queue_free()
	await process_frame
	print("TEAM_PINGS_PASS bounds=ok rate=ok replay=ok clear=ok expiry=ok team_privacy=ok dead=ok map_input=ok solo=ok round_reset=ok")
	quit()
