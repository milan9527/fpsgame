extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.world.block(Vector3(0, 1.5, 0), Vector3(6, 3, 2), "657477")
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.zone_state = {}
	game.zone = 110
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 105)
	var actor = game.actors[-1]
	var target = game.actors[1]
	actor.position = Vector3(5, 0.02, 4)
	target.position = Vector3(0, 0.02, -12)
	actor.health = 30
	actor.armor = 0
	actor.ammo = 15
	actor.medkits = 2
	actor.bot_think = 0
	for i in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	assert(game.world.navigation_ready())
	assert(game.visible_target(actor, target))
	var cover = actor.navigator.cover
	var selected: Vector3 = cover.select(actor, game.world, target.position, Vector2.ZERO, 110, true, true, 0.02)
	assert(selected.is_finite(), "Nearby solid cover must be found")
	assert(cover.protected(game.world, selected, target.position))
	assert(not cover.protected(game.world, actor.position, target.position))
	actor.navigator.goal = selected + Vector3.RIGHT
	actor.navigator.path = PackedVector3Array([actor.position])
	actor.navigator.repath_left = 0
	actor.navigator.steer(actor, game.world, selected, 0.02, 0.1)
	assert(actor.navigator.goal == selected, "Close cover goals still require a precise repath")
	cover.clear()
	cover.search_left = 0
	assert(not cover.select(actor, game.world, target.position, Vector2.ZERO, 110, true, false, 0.02).is_finite(), "No omniscient search without an observed threat")
	var crouched_in_cover := false
	var treated := false
	for tick in range(600):
		await physics_frame
		game.bot_input(actor, 1.0 / 60)
		actor.simulate(1.0 / 60)
		if actor.crouched and actor.heal_left > 0:
			assert(cover.protected(game.world, actor.position, target.position))
			crouched_in_cover = true
		if actor.health > 30:
			treated = true
			break
	assert(crouched_in_cover and treated, "Bot must physically reach cover and finish real treatment")
	actor.health = 30
	actor.bot_last_seen = target.position
	actor.bot_memory_left = 3
	cover.point = selected
	cover.hold_left = 8
	game.zone_center = Vector2(50, 0)
	game.zone = 10
	game.bot_input(actor, 1.0 / 60)
	assert(actor.sprint and not actor.crouch and not cover.point.is_finite(), "Zone evacuation overrides tactical cover")
	cover.search_left = 0
	assert(not cover.select(actor, game.world, target.position, Vector2(100, 100), 4, true, true, 1).is_finite(), "Unsafe cover rejected")
	print("BOT_COVER_RULES_PASS visibility=ok reachable=ok physical_arrival=ok crouch_heal=ok known_threat=ok zone_priority=ok")
	game.request_quit()
