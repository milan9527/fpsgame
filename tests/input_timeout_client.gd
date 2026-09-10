extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 40000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	while game.phase != "live" or not game.actors.has(game.local_id):
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	var actor = game.actors[game.local_id]
	actor.pitch = 1.2
	for action in ["forward", "fire", "aim", "lean_left", "crouch"]:
		Input.action_press(action)
	await create_timer(0.8).timeout
	assert(actor.ammo < 30 and actor.aiming and actor.crouched)
	# Stop all outgoing input while ENet continues receiving authoritative snapshots.
	game.set_physics_process(false)
	await create_timer(1.0).timeout
	var state: Dictionary = actor.pending_correction
	assert(not state.is_empty())
	assert(not state.ads and not state.crouched and absf(state.lean) < 0.1, "Authoritative snapshot must release held stance")
	assert(Vector2(state.vel.x, state.vel.z).length() < 0.1)
	var ammo: int = actor.ammo
	await create_timer(0.5).timeout
	assert(actor.ammo == ammo, "Authority must stop sustained firing without new input")
	for action in ["forward", "fire", "aim", "lean_left", "crouch"]:
		Input.action_release(action)
	var position: Vector3 = state.p
	var ack: int = state.ack
	Input.action_press("forward")
	game.set_physics_process(true)
	await create_timer(0.8).timeout
	Input.action_release("forward")
	assert(actor.target_position.distance_to(position) > 1 and actor.prediction_ack > ack, "Authority must acknowledge and move after input resumes")
	print("INPUT_TIMEOUT_NETWORK_PASS real_enet=ok held_state=neutral firing_stopped=ok movement_resumed=ok")
	game.request_quit()
