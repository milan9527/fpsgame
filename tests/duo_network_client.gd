extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.sign_in(OS.get_environment("TEST_USERNAME"), OS.get_environment("TEST_PASSWORD"), false, game.api_url, "duo")
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if game.phase != "live" or game.actors.size() != 16:
			continue
		assert(game.match_mode == "duo")
		var humans := {}
		var counts := {}
		for actor in game.actors.values():
			assert(actor.team_id > 0)
			counts[actor.team_id] = counts.get(actor.team_id, 0) + 1
			if actor.actor_id > 0:
				humans[actor.team_id] = humans.get(actor.team_id, 0) + 1
		assert(counts.size() == 8 and humans.size() == 2)
		for count in counts.values():
			assert(count == 2)
		for count in humans.values():
			assert(count == 2)
		print("DUO_NETWORK_CLIENT_PASS peer=%d mode=duo actors=16 teams=8 human_pairs=2" % game.local_id)
		game.request_quit()
		return
	assert(false, "Duo admission and team snapshots timed out")
