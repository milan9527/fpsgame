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
	game.set_process(false)
	game.elapsed = 20
	game.zone_state = {}
	game.zone = 110
	game.loot.clear()
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 105)
	var actor = game.actors[-1]
	var target = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	target.position = Vector3(0, 0.02, -6)
	actor.health = 30
	actor.armor = 0
	actor.smokes = 2
	actor.grenades = 0
	actor.medkits = 2
	actor.bot_last_seen = target.position
	actor.bot_memory_left = 0
	actor.shooting = false
	var utility = actor.navigator.utilities
	utility.update(game, actor, 1, false, false)
	assert(actor.smokes == 2, "No smoke decision without an observed threat")
	actor.bot_memory_left = 3
	utility.update(game, actor, 1, true, false)
	assert(actor.smokes == 2, "Solid cover takes priority over spending smoke")
	utility.update(game, actor, 1, false, true)
	assert(actor.smokes == 2, "Zone evacuation cannot trigger smoke camping")
	actor.reload_left = 1
	utility.update(game, actor, 1, false, false)
	assert(actor.smokes == 2, "Timed actions still gate throwing")
	actor.reload_left = 0
	var yaw: float = actor.yaw
	var pitch: float = actor.pitch
	utility.update(game, actor, 1, false, false)
	assert(actor.smokes == 1 and game.grenades.size() == 1 and utility.smoke_hold == 8)
	assert(actor.yaw == yaw and actor.pitch == pitch and actor.move_input == Vector2.ZERO)
	assert(actor.crouch and not actor.shooting)
	assert(game.grenades.values()[0].kind == 1)
	actor.navigator.cover.search_left = 100
	var concealed_treatment := false
	for tick in range(600):
		await physics_frame
		game.bot_input(actor, 1.0 / 60)
		actor.simulate(1.0 / 60)
		game.advance_grenades(1.0 / 60)
		if game.smoke_clouds.is_empty():
			assert(actor.heal_left == 0, "No treatment before the real smoke exists")
		if actor.heal_left > 0:
			assert(game.smoke_blocks(actor.eye_position(), utility.smoke_threat + Vector3.UP * 1.6))
			concealed_treatment = true
		if actor.health > 30:
			break
	assert(concealed_treatment and actor.health > 30 and actor.medkits == 1, "Physical grenade must produce useful cover and completed treatment")
	assert(actor.smokes == 1, "Tactics do not repeatedly spend inventory")
	utility.update(game, actor, 0.01, false, true)
	assert(utility.smoke_hold == 0, "Evacuation interrupts the smoke hold")
	game.clear_grenades()
	actor.health = 100
	actor.heal_left = 0
	actor.throw_left = 0
	actor.smokes = 0
	actor.grenades = 2
	actor.target_id = 1
	actor.bot_last_seen = actor.position + Vector3.FORWARD * 26
	actor.shooting = true
	utility.cooldown = 0
	utility.think_left = 0
	utility.update(game, actor, 0.01, false, false)
	assert(actor.grenades == 1 and utility.cooldown == 12)
	actor.throw_left = 0
	utility.update(game, actor, 1, false, false)
	assert(actor.grenades == 1, "Frag follow-up respects tactical cooldown")
	print("BOT_UTILITIES_RULES_PASS known_threat=ok cover_priority=ok zone_priority=ok action_gates=ok real_smoke=ok treatment=ok stock=ok frag_cooldown=ok")
	game.request_quit()
