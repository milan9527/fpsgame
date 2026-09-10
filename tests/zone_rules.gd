extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var plan = load("res://scripts/zone_rules.gd").new()
	for seed_value in range(100):
		plan.reset(seed_value)
		var previous: Dictionary = plan.sample(0)
		for tick in range(3001):
			var state: Dictionary = plan.sample(tick / 10.0)
			assert(state.center.distance_to(state.next_center) + state.next_radius <= state.radius + 0.001)
			assert(state.center.length() + state.radius <= 110.001)
			assert(state.radius <= previous.radius + 0.001)
			assert(state.center.distance_to(previous.center) < 0.2)
			assert(state.remaining >= 0 and state.stage >= 1 and state.stage <= 6)
			previous = state
	assert(plan.sample(34.9).radius == 110 and not plan.sample(34.9).moving)
	assert(plan.sample(35).moving and plan.sample(65).radius == 80)
	assert(plan.sample(285).radius == 4 and plan.sample(300).remaining == 0)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	for tick in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	game.zone = 10
	game.zone_center = Vector2(30, 20)
	game.zone_state = {"center": game.zone_center, "radius": 10.0, "next_center": Vector2(31, 20), "next_radius": 4.0, "stage": 6, "moving": true, "remaining": 10.0}
	var actor = game.actors[-1]
	actor.position = Vector3(0, 0.02, 0)
	actor.bot_think = 100
	game.bot_input(actor, 1.0 / 60)
	assert(actor.sprint and actor.navigator.goal == Vector3(30, 0, 20))
	var human = game.actors[1]
	human.position = Vector3(30, 0.02, 20)
	game._process(0)
	assert(game.world.zone_mesh.position == Vector3(30, 8, 20))
	assert(not "RETURN TO THE SAFE ZONE" in game.ui.prompt.text)
	human.position = Vector3.ZERO
	game._process(0)
	assert("RETURN TO THE SAFE ZONE" in game.ui.prompt.text)
	if "--capture-zones" in OS.get_cmdline_user_args():
		game.ui.set_map(true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/safe-zones.png")
	print("ZONE_RULES_PASS nested=100_seeds continuity=ok stages=ok off_center_bot=ok hud_world=ok")
	game.queue_free()
	await process_frame
	quit()
