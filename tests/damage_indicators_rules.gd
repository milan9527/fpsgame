extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var marks = load("res://scripts/damage_indicators.gd").new()
	marks.record(Vector3(0, 0, -10), Vector3.ZERO, 100)
	marks.record(Vector3(10, 0, 0), Vector3.ZERO, 100)
	marks.record(Vector3(-10, 0, 0), Vector3.ZERO, 100)
	assert(marks.marks.size() == 3)
	var view: Array = marks.visible_marks(0, 100)
	assert(is_equal_approx(view[0].angle, -PI / 2))
	assert(is_zero_approx(view[1].angle))
	assert(is_equal_approx(absf(view[2].angle), PI))
	view = marks.visible_marks(PI / 2, 100)
	assert(is_zero_approx(view[0].angle))
	marks.record(Vector3(0.1, 0, -10), Vector3.ZERO, 200)
	assert(marks.marks.size() == 3 and marks.marks[0].until == 1100)
	marks.record(Vector3(0, 20, 0), Vector3.ZERO, 200)
	assert(marks.marks.size() == 3, "Vertical/self damage has no false horizontal direction")
	marks.resume(300, 5300)
	assert(marks.visible_marks(0, 5300).size() == 3)
	assert(marks.visible_marks(0, 6100).is_empty())
	for index in range(20):
		marks.record(Vector3(cos(index * 0.3), 0, sin(index * 0.3)) * 10, Vector3.ZERO, 7000 + index)
	assert(marks.marks.size() == 8)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	var player = game.actors[1]
	game._process(0)
	game.android_profile_enabled = true
	game.damage(player, 1, -1, true)
	assert(("cause:%s," % game.actors[-1].NAMES[game.actors[-1].weapon]) in game.android_last_damage,
		"Weapon damage must not be reported as zone damage")
	game.damage(player, 1, 0, true)
	assert("cause:THE ZONE," in game.android_last_damage)
	game.damage(player, 1, -1, true, false, "FRAG")
	assert("cause:FRAG," in game.android_last_damage)
	game.android_profile_enabled = false
	game.ui.damage_indicators.marks.clear()
	for offset in [Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
		game.damage(player, 1, 0, true, false, "FRAG", player.position + offset * 10)
	assert(game.ui.damage_indicators.marks.size() == 3)
	game.ui.set_pause(true)
	await create_timer(1.1, true).timeout
	game.ui.set_pause(false)
	assert(game.ui.damage_indicators.visible_marks(player.yaw, Time.get_ticks_msec()).size() == 3)
	game.ui.set_spectator(true, "TEST", 2)
	assert(game.ui.damage_indicators.marks.is_empty())
	game.ui.combat_feedback(1, 10, false, false, player.position + Vector3.RIGHT * 10)
	game.ui.show_game()
	assert(game.ui.damage_indicators.marks.is_empty())
	print("DAMAGE_INDICATORS_PASS directions=ok rotation=ok coalescing=ok expiry=ok bound=ok authoritative_feedback=ok pause=ok spectator=ok round_clear=ok")
	game.request_quit()
