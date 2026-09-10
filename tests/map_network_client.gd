extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.set_physics_process(false)
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 15000
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline, "Map fixture admission timed out")
		await process_frame
	game.bot_client = false
	game.ui.set_map(true)
	game.set_physics_process(true)
	var actor = game.actors[game.local_id]
	while actor.position.distance_to(Vector3(0, 0.02, 20)) > 0.2:
		assert(Time.get_ticks_msec() < deadline, "Player position did not reconcile")
		await process_frame
	var map = game.ui.tactical_map
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.world_to_map(Vector2(30, 40))
	map._gui_input(click)
	var before: float = game.phase_time
	var before_ammo: int = actor.ammo
	var before_position: Vector3 = actor.position
	Input.action_press("forward")
	Input.action_press("fire")
	Input.action_press("aim")
	await create_timer(1.5).timeout
	assert(not paused and game.phase_time < before - 1)
	assert(map.visible and actor.ammo == before_ammo)
	assert(actor.position.distance_to(before_position) < 0.2)
	assert(map.operator_position.distance_to(Vector2(actor.position.x, actor.position.z)) < 0.1)
	assert(is_equal_approx(map.zone_radius, game.zone) and "36m" in game.ui.waypoint_label.text)
	assert(game.zone_center.length() > 0.1 and game.zone_state.moving)
	assert(map.zone_info == game.zone_state and game.world.zone_mesh.position.distance_to(Vector3(game.zone_center.x, 8, game.zone_center.y)) < 0.1)
	Input.action_release("forward")
	Input.action_release("fire")
	Input.action_release("aim")
	game.ui.set_map(false)
	assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and map.waypoint != null)
	print("MAP_NETWORK_CLIENT_PASS authenticated=ok round_continues=ok neutral_movement=ok no_fire=ok marker=ok authoritative_position_zone=ok")
	game.request_quit()
