extends SceneTree

var game
var reported := false

func _initialize() -> void:
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child.call_deferred(game)

func _process(_delta: float) -> bool:
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
