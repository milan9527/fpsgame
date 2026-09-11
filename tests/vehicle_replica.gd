extends SceneTree
const Wire = preload("res://scripts/vehicle_snapshot.gd")
const Replica = preload("res://scripts/vehicle_replica.gd")
const Seats = preload("res://scripts/vehicle_seats.gd")
var round_id := ""

func _initialize() -> void:
	call_deferred("run")

func frame(sequence: int, states: Array) -> Dictionary:
	var receiver = Wire.new()
	receiver.reset(round_id)
	var result := {}
	for bytes in Wire.encode(round_id, sequence, states):
		result = receiver.receive(bytes, 0)
	assert(not result.is_empty())
	return result

func poses(sequence: int, states: Array, extra := {}) -> Dictionary:
	var positions: Dictionary = extra.duplicate()
	for state in states:
		for index in range(2):
			if state.seats[index] != 0:
				positions[state.seats[index]] = state.p + Basis(Vector3.UP, state.yaw) * Seats.ANCHORS[index]
	return {"round": round_id, "sequence": sequence, "positions": positions}

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	round_id = game.match_id
	var driver = game.actors[1]
	var passenger = game.actors[-1]
	driver.position = Vector3(-1.65, 0.04, 0.1)
	passenger.position = Vector3(1.65, 0.04, 0.1)
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	var wreck = game.vehicle_fleet.spawn(game, Vector3(12, 0, 0))
	await physics_frame
	await physics_frame
	for _step in range(5):
		game.vehicle_fleet.step(1.0 / 60, true)
	assert(car.seats.enter(driver, 0) and car.seats.enter(passenger, 1))
	wreck.take_damage(1000)
	var states: Array = Wire.capture(game.vehicle_fleet)
	var replica = Replica.new()
	replica.reset(game, round_id)
	game.online = true
	# Hold the old world until both actor roster and matching poses are present.
	var first := frame(1, states)
	assert(not replica.apply_frame(game, first, poses(0, states)))
	assert(game.vehicle_fleet.vehicles.is_empty())
	game.actors.erase(-1)
	assert(not replica.apply_frame(game, first, poses(1, states)))
	assert(game.vehicle_fleet.vehicles.is_empty() and replica.last_sequence == -1)
	game.actors[-1] = passenger
	var wrong := poses(1, states)
	wrong.positions[1] += Vector3(5, 0, 0)
	assert(not replica.apply_frame(game, first, wrong))
	assert(replica.apply_frame(game, first, poses(1, states)))
	car = game.vehicle_fleet.vehicles[1]
	wreck = game.vehicle_fleet.vehicles[2]
	assert(driver.is_seated() and passenger.is_seated() and driver.vehicle_seat == 0)
	assert(not car.authoritative and car.collision_layer == 4 and car.collision_mask == 0)
	var fuel: float = car.fuel
	var position: Vector3 = car.position
	assert(not car.command(1, 0, 1, 0, false, car.seats.epoch))
	assert(car.take_damage(500) == 0)
	car.simulate(0.016)
	assert(car.position == position and car.fuel == fuel and car.health == 600)
	assert(wreck.destroyed and driver.health == 100 and passenger.health == 100)
	assert(not replica.apply_frame(game, first, poses(1, states)))
	states[0].p.x += 1
	states[0].wheels = [1.0, 1.0, 1.0, 1.0]
	assert(replica.apply_frame(game, frame(2, states), poses(2, states)))
	assert(car.position == position, "Normal updates interpolate rather than immediately teleport")
	replica.render(game, 0.025)
	assert(absf(car.position.x - 0.5) < 0.001)
	assert(driver.position.is_equal_approx(car.to_global(Seats.ANCHORS[0])))
	assert(car.wheel_rigs[0].roll.rotation.x > 0.4)
	# An older walking snapshot/prediction cannot pull a seated actor away.
	passenger.target_position = Vector3(99, 0, 99)
	var seated_position: Vector3 = passenger.position
	passenger.render_frame(0.1, true, false, false)
	assert(passenger.position == seated_position)
	driver.pending_correction = {"ack": 100, "p": Vector3(99, 0, 99)}
	driver.predict_movement({}, 0.016, true)
	assert(driver.pending_correction.is_empty() and driver.prediction_history.is_empty())
	assert(driver.position.is_equal_approx(car.to_global(Seats.ANCHORS[0])))
	# Reject a seat change without an authoritative epoch change atomically.
	var invalid := states.duplicate(true)
	invalid[0].seats = [-1, 1]
	invalid[0].driver = -1
	assert(not replica.apply_frame(game, frame(3, invalid), poses(3, invalid)))
	assert(driver.vehicle_seat == 0 and replica.last_sequence == 2)
	states[0].p.x = 30
	assert(replica.apply_frame(game, frame(3, states), poses(3, states)))
	assert(car.position.x == 30, "Large authority corrections snap the vehicle")
	states[0].epoch += 1
	states[0].seats = [-1, 1]
	states[0].driver = -1
	assert(replica.apply_frame(game, frame(4, states), poses(4, states)))
	assert(driver.vehicle_seat == 1 and passenger.vehicle_seat == 0 and car.driver_id == -1)
	# Removing occupied vehicles requires same-frame exit positions.
	var empty := frame(5, [])
	assert(not replica.apply_frame(game, empty, poses(5, [])))
	assert(game.vehicle_fleet.vehicles.size() == 2 and driver.is_seated())
	var exits := {1: Vector3(32, 0.04, 0), -1: Vector3(28, 0.04, 0)}
	assert(replica.apply_frame(game, empty, poses(5, [], exits)))
	assert(game.vehicle_fleet.vehicles.is_empty() and not driver.is_seated() and not passenger.is_seated())
	assert(driver.position == exits[1] and passenger.position == exits[-1])
	assert(driver.collision_mask == 7 and passenger.collision_mask == 7)
	var old_round := round_id
	round_id = game.uuid4()
	replica.reset(game, round_id)
	first.round = old_round
	assert(not replica.apply_frame(game, first, poses(1, states)))
	assert(replica.last_sequence == -1 and replica.targets.is_empty())
	game.online = false
	game.running = false
	game.queue_free()
	await process_frame
	print("VEHICLE_REPLICA_PASS paired_frame=ok late_roster=ok pose_coherence=ok display_only=ok wreck_no_injury=ok interpolation=ok seated_prediction=ok epoch=ok teleport=ok seat_swap=ok atomic_removal=ok round_reset=ok")
	quit()
