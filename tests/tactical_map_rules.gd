extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 0)
	var map = game.ui.tactical_map
	assert(map.features == game.world.map_features)
	var buildings := 0
	for feature in map.features:
		if feature.kind == "building":
			buildings += 1
	assert(buildings == 16)
	for point in [Vector2.ZERO, Vector2(-119, -119), Vector2(119, 119), Vector2(35, -70)]:
		assert(map.map_to_world(map.world_to_map(point)).distance_to(point) < 0.0001)
	assert(not map.mark(Vector2(121, 0)) and not map.mark(Vector2(NAN, 0)))
	assert(not map.mark(Vector2(116, 0)) and not map.mark(Vector2(0, -116)))
	var key := InputEventAction.new()
	key.action = "map"
	key.pressed = true
	game._unhandled_input(key)
	assert(map.visible and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_map(Vector2(30, 40))
	map._gui_input(click)
	assert(map.waypoint.distance_to(Vector2(30, 40)) < 0.0001)
	game._process(0.016)
	assert(game.ui.waypoint_label.visible and "50m" in game.ui.waypoint_label.text)
	Input.action_press("forward")
	Input.action_press("fire")
	Input.action_press("aim")
	var cmd: Dictionary = game.local_command(actor)
	assert(cmd.x == 0 and cmd.z == 0 and not cmd.fire and not cmd.ads and not game.has_actions(cmd))
	var before_yaw: float = actor.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 100)
	game._unhandled_input(motion)
	assert(actor.yaw == before_yaw)
	var before: float = game.phase_time
	game._physics_process(0.1)
	assert(game.phase_time < before, "Map does not pause the offline operation")
	Input.action_release("forward")
	if "--capture-map" in OS.get_cmdline_user_args():
		game._process(0.016)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/tactical-map.png")
	key.action = "pause"
	game._unhandled_input(key)
	assert(not map.visible and not game.ui.pause_panel.visible)
	cmd = game.local_command(actor)
	assert(not cmd.fire and not cmd.ads, "Map close click cannot shoot")
	Input.action_release("fire")
	Input.action_release("aim")
	game.local_command(actor)
	game.ui.set_map(true)
	game.ui.set_inventory(true)
	assert(not map.visible and game.ui.inventory.visible)
	game.ui.set_map(true)
	assert(map.visible and not game.ui.inventory.visible)
	game.ui.set_pause(true)
	assert(paused and not map.visible and map.waypoint != null)
	game.ui.set_pause(false)
	game.ui.set_map(true)
	click.button_index = MOUSE_BUTTON_RIGHT
	map._gui_input(click)
	assert(map.waypoint == null)
	map.mark(Vector2(30, 40))
	game.zone = 70
	game._process(0.016)
	assert(map.zone_radius == 70)
	game.damage(actor, 10000, 0, true)
	game._process(0.016)
	assert(not map.visible and map.waypoint == null)
	map.mark(Vector2(30, 40))
	game.start_solo()
	assert(map.waypoint == null)
	game.leave()
	assert(not map.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("TACTICAL_MAP_RULES_PASS geometry=ok coordinates=ok bounds=ok marker=ok distance=ok inputs=ok menu_exclusion=ok zone=ok death=ok reset=ok")
	game.queue_free()
	await process_frame
	quit()
