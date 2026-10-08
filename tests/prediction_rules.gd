extends SceneTree

const Actor = preload("res://scripts/actor.gd")
const DT := 1.0 / 60

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)
	var server = Actor.new()
	var client = Actor.new()
	stage.add_child(server)
	stage.add_child(client)
	# Co-located independent simulations collide with the same environment,
	# but not each other.
	server.collision_mask = 1
	client.collision_mask = 1
	for i in range(5):
		await physics_frame
		server.simulate(DT)
		client.simulate(DT)
	var transit: Array[Dictionary] = []
	var maximum_error := 0.0
	var sequence := 0
	# Delayed authoritative snapshots, turns, sprint, crouch and jump.
	# The server accepts inputs at 30Hz; each state still advances at 60Hz.
	for tick in range(180):
		await physics_frame
		sequence += 1
		var cmd := {"seq": sequence, "x": 0.0, "z": -1.0 if tick < 130 else 0.0, "yaw": 0.0 if tick < 65 else 0.8, "crouch": tick >= 90 and tick < 125, "sprint": tick < 60, "ads": false, "fire": false, "jump": tick == 40 or tick == 41}
		if tick % 2 == 0:
			server.move_input = Vector2(cmd.x, cmd.z)
			server.yaw = cmd.yaw
			server.sprint = cmd.sprint
			server.crouch = cmd.crouch
			server.jump_requested = cmd.jump
			server.last_sequence = sequence
		server.simulate(DT)
		if tick % 3 == 0:
			transit.append({"due": tick + 12, "state": server.pack()})
		while not transit.is_empty() and int(transit[0].due) <= tick:
			client.unpack(transit.pop_front().state, true)
		client.predict_movement(cmd, DT, true)
		if tick == 1:
			assert(client.position.z < -0.2, "Movement responds before any snapshot arrives")
		if tick > 20:
			maximum_error = maxf(maximum_error, client.position.distance_to(server.position))
		assert(client.prediction_history.size() <= Actor.PREDICTION_LIMIT)
	assert(maximum_error < 0.8, "Delayed correction remains bounded across movement transitions: " + str(maximum_error))
	assert(client.position.distance_to(server.position) < 0.08, "Stopped player converges to authority")
	assert(client.prediction_corrections > 40)
	# Replaying movement must never complete reload/healing or consume ammo.
	client.reload_left = 0.001
	client.heal_left = 0.001
	client.ammo = 1
	client.health = 30
	var state: Dictionary = server.pack()
	state.ack = sequence - 6
	client.pending_correction = state
	client.reconcile_movement()
	assert(client.ammo == 1 and client.health == 30 and client.medkits == 2)
	# Excessive discontinuity snaps rather than replaying stale motion.
	state = server.pack()
	state.p = Vector3(25, 0, 25)
	state.ack = sequence
	client.pending_correction = state
	client.reconcile_movement()
	assert(client.position.distance_to(state.p) < 0.001)
	assert(client.prediction_history.is_empty() and client.camera_error == Vector3.ZERO)
	client.heal_left = 0
	client.reload_left = 0
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(5, 4, 0.25)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(25, 2, 22)
	stage.add_child(wall)
	await physics_frame
	for tick in range(40):
		await physics_frame
		sequence += 1
		client.predict_movement({"seq": sequence, "x": 0.0, "z": -1.0, "yaw": 0.0, "sprint": true, "crouch": false, "ads": false, "fire": false, "jump": false}, DT, true)
	assert(client.position.z > 22.49, "Predicted body cannot walk through wall")
	# Rewind and replay all forty inputs through the same wall.
	client.pending_correction = state.duplicate()
	client.reconcile_movement()
	assert(client.position.z > 22.49 and client.position.z < 22.6, "Replayed movement also respects wall")
	var collision_position: Vector3 = client.position
	client.camera_error = Vector3(0, 0, -0.5)
	client.render_frame(0.001, true, true, false)
	assert(client.position == collision_position, "Visual smoothing never moves the collision body")
	assert(client.camera.global_position.z > 22.24, "Camera correction stops before wall")
	# Alternate correction directions to detect stale endpoints on the reused ray.
	var correction_query = client.camera_correction_query
	assert(correction_query != server.camera_correction_query)
	for offset in [Vector3(0, 0, -0.5), Vector3(0.3, 0, 0.5), Vector3.ZERO, Vector3(0, 0, -0.7)]:
		client.camera_error = offset
		client.render_frame(0.001, true, true, false)
		assert(client.camera_correction_query == correction_query)
		var origin: Vector3 = client.camera.get_parent().to_global(Vector3.ZERO)
		var expected: Vector3 = origin + client.camera_error
		if client.camera_error.length_squared() > 0.000001:
			var reference := PhysicsRayQueryParameters3D.create(origin, expected, 5)
			var hit := stage.get_world_3d().direct_space_state.intersect_ray(reference)
			if not hit.is_empty():
				expected = origin + client.camera_error.normalized() * maxf(0, origin.distance_to(hit.position) - 0.12)
		assert(client.camera.global_position.is_equal_approx(expected), "Reused camera query matches fresh ray")
		assert(client.position == collision_position)
	# A prolonged outage must not cause unbounded memory or stale replay.
	for tick in range(125):
		await physics_frame
		sequence += 1
		client.predict_movement({"seq": sequence, "x": 0.0, "z": 0.0, "yaw": 0.0, "sprint": false, "crouch": false, "ads": false, "fire": false, "jump": false}, DT, true)
	assert(client.prediction_history.size() == Actor.PREDICTION_LIMIT)
	client.pending_correction = state.duplicate()
	client.reconcile_movement()
	assert(client.prediction_history.is_empty() and client.position.distance_to(state.p) < 0.001, "Unavailable history falls back to authority")
	# A dead local actor applies the authority position and cannot keep moving.
	state.live = false
	state.h = 0
	client.unpack(state, true)
	client.predict_movement({"seq": sequence + 1}, DT, true)
	assert(not client.alive and client.prediction_history.is_empty())
	assert(client.position.distance_to(state.p) < 0.001)
	print("PREDICTION_RULES_PASS immediate=ok delayed_200ms=ok error=%.3f convergence=ok no_gameplay_replay=ok wall=ok bounded_history=ok teleport=ok death=ok" % maximum_error)
	stage.queue_free()
	await process_frame
	quit()
