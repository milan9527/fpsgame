extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 22000
	while not game.running or game.phase != "live":
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	if OS.get_environment("RECAP_OBSERVER") == "1":
		await create_timer(9).timeout
		assert(game.ui.death_recap.is_empty() and not game.ui.recap_panel.visible)
		print("DEATH_RECAP_OBSERVER_PASS private_report=ok")
	else:
		while game.ui.death_recap.is_empty() or not game.ui.recap_panel.visible:
			assert(Time.get_ticks_msec() < deadline)
			await process_frame
		var report: Dictionary = game.ui.death_recap
		assert(report.source == OS.get_environment("ATTACKER_USERNAME"))
		assert(report.cause == "SR-5 / MARKSMAN" and report.headshot)
		assert(report.health_damage == 42 and report.armor_damage == 15)
		assert(game.spectator.active and report.distance >= 0)
		game.death_report("stale", {"source": "BAD"})
		assert(game.ui.death_recap == report)
		print("DEATH_RECAP_NETWORK_PASS authority=ok spectator=ok final_hit=ok round_guard=ok")
	game.request_quit()
