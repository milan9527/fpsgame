extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	var player = game.actors[1]
	var attacker = game.actors[-1]
	attacker.display_name = "RIVAL"
	attacker.weapon = 2
	player.position = Vector3(0, 1, 20)
	attacker.position = Vector3(30, 1, 20)
	player.health = 35
	player.armor = 20
	game.damage(player, 2, -1, true)
	assert(game.ui.death_recap.is_empty(), "Nonlethal damage does not show a death report")
	var health: float = player.health
	var armor: float = player.armor
	game.damage(player, 500, -1, true, true)
	var report: Dictionary = game.ui.death_recap.duplicate()
	assert(report.source == "RIVAL" and report.cause == attacker.NAMES[2] and report.headshot)
	assert(is_equal_approx(report.distance, 30))
	assert(is_equal_approx(report.health_damage, health) and is_equal_approx(report.armor_damage, armor))
	game._process(0)
	assert(game.ui.recap_panel.visible and game.spectator.active)
	game.damage(player, 1000, 0, true)
	assert(game.ui.death_recap == report, "Repeated death cannot overwrite the final hit")
	game.death_report("old-round", {"source": "STALE"})
	assert(game.ui.death_recap == report)
	game.ui.set_pause(true)
	await process_frame
	game.ui.set_pause(false)
	assert(game.ui.death_recap == report)
	if OS.has_environment("CAPTURE_PATH"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	for cause in ["FRAG", "FALL", "THE ZONE"]:
		game.start_solo()
		assert(game.ui.death_recap.is_empty() and not game.ui.recap_panel.visible)
		player = game.actors[1]
		player.armor = 0
		game.damage(player, 500, 1 if cause == "FRAG" else 0, true, false, cause, player.position + Vector3.RIGHT * 3 if cause == "FRAG" else null)
		report = game.ui.death_recap.duplicate(true)
		assert(report.cause == cause and not report.headshot)
		assert(report.source == ("YOURSELF" if cause == "FRAG" else cause))
		assert(is_equal_approx(report.distance, 3 if cause == "FRAG" else -1))
	game.start_solo()
	game.participants[99] = {"kills": 0, "rank": 0, "user_id": ""}
	game.damage(game.actors[1], 500, 99, true, false, "FRAG", game.actors[1].position)
	assert(game.ui.death_recap.source == "DISCONNECTED OPERATOR")
	game.start_solo()
	game.online = true
	game.network_round_id = "network-round"
	game.death_report(game.match_id, report)
	assert(game.ui.death_recap.is_empty())
	game.death_report("network-round", report)
	assert(not game.ui.death_recap.is_empty())
	game.new_round("next-round")
	assert(game.ui.death_recap.is_empty() and not game.ui.recap_panel.visible)
	game.online = false
	print("DEATH_RECAP_RULES_PASS final_hit=ok causes=ok overkill=ok spectator=ok pause=ok duplicate=ok round_isolation=ok")
	game.request_quit()
