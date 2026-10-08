extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await physics_frame
	var samples := 0
	for yaw in [-PI, -1.2, 0.0, 0.7, PI]:
		for input in [Vector2.ZERO, Vector2(0.00001, 0), Vector2(1, 0),
				Vector2(0, -1), Vector2(-0.3, 0.7)]:
			actor.position = Vector3(0, 20, 0)
			actor.yaw = yaw
			actor.move_input = input
			actor.velocity = Vector3.ZERO
			var expected := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y) * 5.5
			actor.move_step(1.0 / 60.0, false)
			assert(is_equal_approx(actor.velocity.x, expected.x))
			assert(is_equal_approx(actor.velocity.z, expected.z))
			samples += 1
	# The existing Android parser decodes everything following route_json.
	var game = load("res://scripts/game.gd").new()
	game.actors[game.local_id] = actor
	var state: String = game.android_gameplay_state()
	var route = JSON.parse_string(state.split(" route_json=", true, 1)[1])
	assert(route is Dictionary and route.has("x") and route.has("alive"))
	var movement = JSON.parse_string(state.split(" movement_json=", true, 1)[1].split(" route_json=", true, 1)[0])
	assert(movement is Dictionary and movement.input.size() == 2)
	assert(movement.velocity.size() == 3 and movement.contacts is Array)
	game.free()
	print("ACTOR_IDLE_MOVEMENT_PASS samples=%d route_parser=compatible movement=valid" % samples)
	actor.queue_free()
	await process_frame
	quit()
