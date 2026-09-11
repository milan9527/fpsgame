extends RefCounted

const Wire = preload("res://scripts/vehicle_snapshot.gd")
var round_id := ""
var last_sequence := -1
var targets: Dictionary = {}

func reset(game, current_round: String) -> void:
	game.vehicle_fleet.clear()
	round_id = current_round
	last_sequence = -1
	targets.clear()

func apply_frame(game, frame: Dictionary, actor_frame: Dictionary) -> bool:
	# Caller pairs complete vehicle data with actor poses from the same server
	# frame. A missing/reordered actor frame leaves the old coherent world intact.
	if not game.online or game.dedicated or not Wire.valid_round(round_id):
		return false
	if frame.get("round") != round_id or actor_frame.get("round") != round_id:
		return false
	if not Wire.identifier(frame.get("sequence")) or not Wire.identifier(actor_frame.get("sequence")) or frame.sequence <= last_sequence or actor_frame.sequence != frame.sequence:
		return false
	if not frame.get("states") is Array or not Wire.valid_states(frame.states) or not actor_frame.get("positions") is Dictionary:
		return false
	var positions: Dictionary = actor_frame.positions
	if positions.size() > 16:
		return false
	var desired := {}
	var by_id := {}
	for state in frame.states:
		by_id[state.id] = state
		if targets.has(state.id):
			var previous: Dictionary = targets[state.id]
			if state.epoch < previous.epoch or (state.epoch == previous.epoch and state.seats != previous.seats):
				return false
			if previous.destroyed and not state.destroyed:
				return false
		for index in range(2):
			var id: int = state.seats[index]
			if id != 0:
				if not game.actors.has(id):
					return false
				desired[id] = {"vehicle": state.id, "seat": index}
	# Validate all affected poses before mutating anything, including actors
	# leaving a seat whose vehicle has disappeared from this complete snapshot.
	for car in game.vehicle_fleet.vehicles.values():
		if car.authoritative:
			return false
		for index in range(2):
			var occupant = car.seats.occupant(index)
			if occupant != null and game.actors.get(occupant.actor_id) == occupant:
				if not positions.has(occupant.actor_id):
					return false
	for id in desired:
		if not positions.has(id):
			return false
	for id in positions:
		if not Wire.identifier(id, -2147483647) or id == 0 or not game.actors.has(id) or not positions[id] is Vector3 or not positions[id].is_finite() or positions[id].length() >= 1000:
			return false
	for id in desired:
		var actor = game.actors[id]
		if actor.is_seated() and not game.vehicle_fleet.vehicles.values().has(actor.vehicle_ref.get_ref()):
			return false
		var seat: Dictionary = desired[id]
		var state: Dictionary = by_id[seat.vehicle]
		var point: Vector3 = state.p + Basis(Vector3.UP, state.yaw) * preload("res://scripts/vehicle_seats.gd").ANCHORS[seat.seat]
		if positions[id].distance_to(point) > 0.1:
			return false
	# Detach changed seats at the paired authoritative actor position.
	for car in game.vehicle_fleet.vehicles.values():
		for index in range(2):
			var actor = car.seats.occupant(index)
			if actor == null:
				car.seats.slots[index] = null
				continue
			var seat: Dictionary = desired.get(actor.actor_id, {})
			if seat.get("vehicle", 0) != car.vehicle_id or seat.get("seat", -1) != index:
				car.seats.release(actor, positions.get(actor.actor_id, actor.position))
				actor.target_position = actor.position
				actor.pending_correction.clear()
				actor.camera_error = Vector3.ZERO
	for id in game.vehicle_fleet.vehicles.keys():
		if not by_id.has(id):
			var removed = game.vehicle_fleet.vehicles[id]
			game.vehicle_fleet.vehicles.erase(id)
			removed.get_parent().remove_child(removed)
			removed.queue_free()
	for state in frame.states:
		var car = game.vehicle_fleet.vehicles.get(state.id)
		if car == null:
			game.vehicle_fleet.next_id = state.id
			car = game.vehicle_fleet.spawn(game, state.p, state.yaw)
			car.authoritative = false
			car.collision_mask = 0
		elif car.position.distance_to(state.p) > 12:
			car.position = state.p
			car.rotation.y = state.yaw
		car.velocity = state.vel
		car.speed = state.speed
		car.steering = state.steering
		car.health = state.health
		car.fuel = state.fuel
		car.grounded = state.grounded
		var was_destroyed: bool = car.destroyed
		car.destroyed = state.destroyed
		if car.destroyed and not was_destroyed:
			car.update_wreck_visual()
		for index in range(2):
			var id: int = state.seats[index]
			if id == 0:
				continue
			var actor = game.actors[id]
			if car.seats.occupant(index) != actor:
				car.seats.slots[index] = {"actor": weakref(actor), "mask": 7, "layer": 2}
				actor.vehicle_ref = weakref(car)
				actor.vehicle_seat = index
				actor.collision_mask = 0
				car.add_collision_exception_with(actor)
				actor.prediction_history.clear()
				actor.pending_correction.clear()
				actor.move_input = Vector2.ZERO
				actor.jump_requested = false
			actor.lean = 0
			actor.lean_input = 0
			car.seats.sync_actor(actor, index)
		car.driver_id = state.driver
		car.input_sequence = state.ack
		car.seats.epoch = state.epoch
	game.vehicle_fleet.next_id = 1 if by_id.is_empty() else int(by_id.keys().max()) + 1
	game.vehicle_fleet.map_spawned = true
	targets = by_id.duplicate(true)
	last_sequence = frame.sequence
	return true

func render(game, dt: float) -> void:
	if not is_finite(dt) or dt < 0:
		return
	var weight := clampf(dt * 20, 0, 1)
	for id in targets:
		var car = game.vehicle_fleet.vehicles.get(id)
		if car == null:
			continue
		var state: Dictionary = targets[id]
		car.position = car.position.lerp(state.p, weight)
		car.rotation.y = lerp_angle(car.rotation.y, state.yaw, weight)
		for index in range(car.wheel_rigs.size()):
			var wheel: Dictionary = car.wheel_rigs[index]
			wheel.roll.rotation.x = lerp_angle(wheel.roll.rotation.x, state.wheels[index], weight)
			wheel.turn.rotation.y = -state.steering if wheel.front else 0.0
		for index in range(2):
			var actor = car.seats.occupant(index)
			if actor != null:
				actor.lean = 0
				actor.lean_input = 0
				car.seats.sync_actor(actor, index)
