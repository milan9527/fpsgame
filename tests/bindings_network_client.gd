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
	var deadline := Time.get_ticks_msec() + 12000
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	game.set_physics_process(true)
	var actor = game.actors[game.local_id]
	while actor.position.distance_to(Vector3(0, 0.02, 20)) > 0.2:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	var path := "user://qa-network-bindings-%d.cfg" % Time.get_ticks_usec()
	game.bindings.path = path
	assert(game.bindings.bind("forward", KEY_T))
	actor.yaw = 0
	var start: Vector3 = actor.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	await create_timer(1.2).timeout
	assert(actor.position.z < start.z - 3 and actor.prediction_corrections > 5, "Remapped physical key drives reconciled online movement")
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	game.ui.set_pause(true)
	game.ui.controls.open()
	await create_timer(0.5).timeout
	start = actor.position
	var remaining: float = game.phase_time
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	await create_timer(1).timeout
	assert(not paused and game.phase_time < remaining - 0.5)
	assert(actor.position.distance_to(start) < 0.2, "Online controls panel neutralizes input")
	game.ui.controls.close()
	game.bindings.reset_defaults()
	DirAccess.remove_absolute(path)
	print("BINDINGS_NETWORK_CLIENT_PASS physical_remap=ok authoritative_movement=ok reconciliation=ok online_panel_neutral=ok round_continues=ok")
	game.request_quit()
