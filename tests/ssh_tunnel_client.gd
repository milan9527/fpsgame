extends SceneTree

var game
var reported := false
var last_second := -1

func _initialize() -> void:
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child.call_deferred(game)

func _process(_delta: float) -> bool:
	# Let the opening live snapshots settle before the 600 ms pause-menu
	# assertion. Scene initialization at the lobby/live boundary can delay
	# packets; the original advancing-round assertion remains unchanged.
	if game != null and game.bot_test_timer >= 19.0 and game.bot_test_timer < 20.0:
		if game.phase != "live" or game.phase_time > 297.0:
			game.bot_test_timer = 19.0
	if game != null and game.actors.has(game.local_id) and int(game.bot_test_timer) != last_second:
		last_second = int(game.bot_test_timer)
		var player = game.actors[game.local_id]
		var fragments := {}
		for sequence in game.vehicle_frames.actor_frames:
			var frame: Dictionary = game.vehicle_frames.actor_frames[sequence]
			fragments[sequence] = {"count": frame.actors.size(), "expected": frame.meta.roster.size(),
				"age_ms": Time.get_ticks_msec() - frame.started}
		print("NETWORK_TIMING ", JSON.stringify({
			"second": last_second, "wall_ms": Time.get_ticks_msec(),
			"phase": game.phase, "phase_time": game.phase_time,
			"paired_sequence": game.vehicle_frames.last_sequence,
			"actor_sequences": game.vehicle_frames.actor_frames.keys(),
			"actor_fragments": fragments,
			"vehicle_sequences": game.vehicle_frames.vehicle_frames.keys(),
			"weapon": player.weapon, "magazines": player.magazines,
			"reserve": player.reserve, "switch_stage": game.test_switch_stage,
			"menu_started": game.test_menu_started, "menu_time": game.test_menu_time
		}))
	if game != null and game.bot_test_timer > 25 and not reported:
		reported = true
		print("SSH_GAME_OBSERVATION ", JSON.stringify({
			"phase": game.phase, "actors": game.actors.size(),
			"moved": game.test_moved, "fired": game.test_fired,
			"lean": game.test_leaned, "remote_lean": game.test_remote_leaned,
			"crouch": game.test_crouched, "recoil": game.test_recoil,
			"remote_crouch": game.test_remote_crouch, "remote_animation": game.test_remote_animation,
			"menu": game.test_menu_done, "magazines": game.test_magazines,
			"weapons": game.test_remote_weapons.size(), "grenade": game.test_grenade_seen,
			"explosion": game.test_grenade_exploded
		}))
	return false
