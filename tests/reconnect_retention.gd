extends SceneTree

class RetentionGame:
	extends "res://scripts/game.gd"
	var heartbeat := {}
	var revoked := []
	func save_outbox() -> void:
		pass
	func http_call(_path: String, body: Dictionary, _internal := false, _method := HTTPClient.METHOD_POST) -> Dictionary:
		heartbeat = body
		return {"code": 200, "body": {"revoked": revoked}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = RetentionGame.new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.reconnect_grace_seconds == 0, "Unfinished reconnect must stay disabled by default")
	for scenario in ["expiry", "last_session", "revoked_heartbeat", "left", "revoked", "disabled"]:
		game.dedicated = false
		game.start_solo("duo")
		game.elapsed = 10
		game.sessions = {1: {"uid": "retained-fixture", "session_version": 3}}
		if scenario != "last_session":
			game.sessions[-1] = {"uid": "other-fixture", "session_version": 0}
		game.participants = {1: {"user_id": "retained-fixture", "team_id": 1, "rank": 0, "kills": 0}}
		game.reconnect_grace_seconds = 0 if scenario == "disabled" else 30
		if scenario == "left":
			game.sessions[1].leaving = true
		if scenario == "revoked":
			game.sessions[1].revoking = true
		var actor = game.actors[1]
		actor.move_input = Vector2.ONE
		actor.shooting = true
		actor.jump_requested = true
		actor.revive_target = -1
		var generation: String = game.match_id
		game.dedicated = true
		game.peer_disconnected(1)
		assert(not game.sessions.has(1))
		if scenario in ["left", "revoked", "disabled"]:
			assert(not game.actors.has(1) and game.retained_sessions.is_empty())
			continue
		assert(game.actors[1] == actor and actor.alive and game.phase == "live")
		game.peer_disconnected(1)
		assert(game.actors[1] == actor and actor.alive, "Duplicate disconnect callbacks must not kill the retained actor")
		assert(actor.move_input == Vector2.ZERO and not actor.shooting and not actor.jump_requested and actor.revive_target == 0)
		assert(game.retained_sessions[1].generation == generation)
		var durability: float = actor.health + actor.armor
		game.damage(actor, 20, 0, true)
		assert(actor.health < 100 and actor.health + actor.armor == durability - 20, "Retained actors must remain vulnerable with normal armor absorption")
		game.revoked = ["retained-fixture"] if scenario == "revoked_heartbeat" else []
		await game.report_room()
		assert("retained-fixture" in game.heartbeat.players and game.heartbeat.session_versions["retained-fixture"] == 3)
		assert(game.heartbeat.reconnectable["retained-fixture"] >= 1 and game.heartbeat.reconnectable["retained-fixture"] <= 30)
		assert(not game.heartbeat.reconnectable.has("other-fixture"))
		if scenario != "revoked_heartbeat":
			var until: int = game.retained_sessions[1].until
			game.retained_sessions[1].until = Time.get_ticks_msec() - 1
			await game.report_room()
			assert(not game.heartbeat.reconnectable.has("retained-fixture"), "Expired seats must not advertise reconnect eligibility")
			game.retained_sessions[1].until = until
			game.retained_sessions[1].generation = "previous-round"
			await game.report_room()
			assert(not game.heartbeat.reconnectable.has("retained-fixture"), "A prior round must not advertise reconnect eligibility")
			game.retained_sessions[1].generation = generation
			game.expire_retained_sessions(until - 1)
			assert(game.actors.has(1))
			game.expire_retained_sessions(until)
		assert(not game.actors.has(1) and game.retained_sessions.is_empty())
		if scenario == "last_session":
			assert(game.phase == "waiting" and game.match_id != generation and game.result_outbox.size() == 1)
			game.result_outbox.clear()
	# Keep a moving driver's body in its seat while normal stale-input braking acts.
	game.dedicated = false
	game.start_solo("duo")
	game.elapsed = 10
	game.sessions = {1: {"uid": "driver-fixture", "session_version": 2}, -1: {"uid": "passenger-fixture", "session_version": 0}}
	game.participants = {1: {"user_id": "driver-fixture", "team_id": 1, "rank": 0, "kills": 0}}
	game.reconnect_grace_seconds = 30
	for other in game.actors.values():
		other.position = Vector3(90, 0.1, 90 + other.actor_id)
	var driver = game.actors[1]
	var passenger = game.actors[-1]
	driver.position = Vector3(-1.65, 0.04, 0.1)
	passenger.position = Vector3(1.65, 0.04, 0.1)
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await physics_frame
	await physics_frame
	for _step in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(driver, 0) and car.seats.enter(passenger, 1))
	for _step in range(90):
		await physics_frame
		car.command(driver.actor_id, car.input_sequence + 1, 1, 0, false, car.seats.epoch)
		car.simulate(1.0 / 60)
	assert(car.speed > 10)
	var initial_speed: float = car.speed
	var initial_position: Vector3 = car.position
	game.dedicated = true
	game.peer_disconnected(1)
	assert(car.throttle == 0 and car.input_age >= car.INPUT_TIMEOUT)
	for _step in range(120):
		await physics_frame
		car.simulate(1.0 / 60)
		assert(driver.is_seated() and passenger.is_seated() and driver.alive)
		assert(car.speed <= initial_speed)
		if absf(car.speed) < 0.01:
			break
	assert(absf(car.speed) < 0.01)
	assert(car.position.distance_to(initial_position) < initial_speed * initial_speed / (2 * car.BRAKING) + 0.5)
	var durability: float = driver.health + driver.armor
	game.damage(driver, 20, 0, true)
	assert(driver.health + driver.armor == durability - 20 and driver.is_seated())
	game.expire_retained_sessions(game.retained_sessions[1].until)
	await physics_frame
	await physics_frame
	car.simulate(1.0 / 60)
	assert(car.seats.occupant(0) == null and car.driver_id == 0 and not game.actors.has(1))
	assert(passenger.is_seated() and passenger.health == 100 and car.health == car.MAX_HEALTH)
	game.dedicated = false
	game.local_recorded_id = game.match_id
	print("RECONNECT_RETENTION_PASS default_disabled=ok input_cleared=ok vulnerable=ok expiry=ok explicit_leave=excluded revoked=excluded heartbeat_revocation=ok last_session_recycle=ok driver_braking=ok driver_seat_cleanup=ok passenger_secured=ok")
	game.request_quit()
