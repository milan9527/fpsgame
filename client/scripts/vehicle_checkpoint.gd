extends RefCounted

const MAX_VEHICLES := 32
const Seats = preload("res://scripts/vehicle_seats.gd")

static func number(value, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func cooldowns_valid(values) -> bool:
	if not values is Dictionary or values.size() > 128:
		return false
	for key in values:
		if not key is String or key.length() > 512 or not number(values[key], 0, 1.001):
			return false
	return true

static func remaining(values: Dictionary, now: float) -> Dictionary:
	var result := {}
	for key in values:
		if values[key] > now:
			result[key] = values[key] - now
	return result

static func capture(game) -> Dictionary:
	var fleet = game.vehicle_fleet
	var items: Array = []
	for id in fleet.vehicles:
		var car = fleet.vehicles[id]
		var seats: Array = []
		for index in range(2):
			var actor = car.seats.occupant(index)
			seats.append(actor.actor_id if actor != null else 0)
		var wheels: Array = []
		for wheel in car.wheel_rigs:
			wheels.append(float(wheel.roll.rotation.x))
		items.append({"id": id, "p": car.position, "yaw": car.rotation.y, "vel": car.velocity,
			"speed": car.speed, "steering": car.steering, "grounded": car.grounded,
			"health": car.health, "fuel": car.fuel, "destroyed": car.destroyed,
			"distance": car.distance_travelled, "seats": seats, "epoch": car.seats.epoch,
			"wheels": wheels, "cooldowns": remaining(car.collision_cooldowns, car.collision_time)})
	var view := Vector3(0, -0.18, 6)
	var actor = game.actors.get(game.local_id)
	if actor != null and actor.is_seated() and actor.vehicle_camera.active:
		view = Vector3(actor.vehicle_camera.orbit_yaw, actor.vehicle_camera.orbit_pitch, actor.vehicle_camera.distance)
	return {"next_id": fleet.next_id, "items": items, "pairs": remaining(fleet.pair_cooldowns, fleet.simulation_time), "view": view}

static func validate(data, actors: Array) -> bool:
	if not data is Dictionary or not data.get("items") is Array or data.items.size() > MAX_VEHICLES:
		return false
	if not data.get("next_id") is int or data.next_id < 1 or data.next_id > 2147483647 or not cooldowns_valid(data.get("pairs")):
		return false
	if not data.get("view") is Vector3 or not data.view.is_finite() or absf(data.view.x) > PI or data.view.y < -0.75 or data.view.y > 0.3 or data.view.z < 3 or data.view.z > 8:
		return false
	var by_id := {}
	for actor in actors:
		by_id[actor.id] = actor
	var ids := []
	var occupied := []
	for car in data.items:
		if not car is Dictionary or not car.get("id") is int or car.id < 1 or car.id >= data.next_id or car.id in ids:
			return false
		ids.append(car.id)
		if not car.get("p") is Vector3 or not car.p.is_finite() or car.p.length() >= 1000:
			return false
		if not car.get("vel") is Vector3 or not car.vel.is_finite() or car.vel.length() > 100:
			return false
		if not number(car.get("yaw"), -PI - 0.001, PI + 0.001) or not number(car.get("speed"), -7.01, 22.01) or not number(car.get("steering"), -0.49, 0.49):
			return false
		if not number(car.get("health"), 0, 600) or not number(car.get("fuel"), 0, 100) or not number(car.get("distance"), 0, 100000):
			return false
		if not car.get("grounded") is bool or not car.get("destroyed") is bool or car.destroyed != (car.health == 0):
			return false
		if not car.get("epoch") is int or car.epoch < 0 or car.epoch >= 2147483647 or not cooldowns_valid(car.get("cooldowns")):
			return false
		if not car.get("wheels") is Array or car.wheels.size() != 4:
			return false
		for angle in car.wheels:
			if not number(angle, -PI - 0.001, PI + 0.001):
				return false
		if not car.get("seats") is Array or car.seats.size() != 2:
			return false
		for index in range(2):
			var id = car.seats[index]
			if not id is int:
				return false
			if id == 0:
				continue
			if id in occupied or not by_id.has(id):
				return false
			occupied.append(id)
			var actor: Dictionary = by_id[id]
			var point: Vector3 = car.p + Basis(Vector3.UP, car.yaw) * Seats.ANCHORS[index]
			if actor.p.distance_to(point) > 0.05 or actor.vel.length() > 0.01 or actor.heal > 0 or actor.reload > 0 or actor.get("revive_target", 0) != 0:
				return false
	for pair in data.pairs:
		var parts: PackedStringArray = pair.split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return false
		var a := int(parts[0])
		var b := int(parts[1])
		if a >= b or a not in ids or b not in ids or pair != "%d:%d" % [a, b]:
			return false
	return true

static func restore(game, data: Dictionary) -> void:
	var fleet = game.vehicle_fleet
	fleet.clear()
	for saved in data.items:
		fleet.next_id = saved.id
		var car = fleet.spawn(game, saved.p, saved.yaw)
		car.velocity = saved.vel
		car.speed = saved.speed
		car.steering = saved.steering
		car.grounded = saved.grounded
		car.health = saved.health
		car.fuel = saved.fuel
		car.destroyed = saved.destroyed
		car.distance_travelled = saved.distance
		car.collision_cooldowns = saved.cooldowns.duplicate()
		car.update_wreck_visual() # Restore appearance without firing injury/death events.
		for index in range(2):
			if saved.seats[index] == 0:
				continue
			var actor = game.actors[saved.seats[index]]
			car.seats.slots[index] = {"actor": weakref(actor), "mask": 7, "layer": 2}
			actor.vehicle_ref = weakref(car)
			actor.vehicle_seat = index
			actor.collision_mask = 0
			car.add_collision_exception_with(actor)
			car.seats.sync_actor(actor, index)
			if index == 0 and actor.alive and not actor.downed and not car.destroyed:
				car.set_driver(actor.actor_id)
		car.seats.epoch = saved.epoch + 1
		for index in range(car.wheel_rigs.size()):
			car.wheel_rigs[index].roll.rotation.x = saved.wheels[index]
			car.wheel_rigs[index].turn.rotation.y = -car.steering if car.wheel_rigs[index].front else 0.0
	fleet.next_id = data.next_id
	fleet.pair_cooldowns = data.pairs.duplicate()
	var actor = game.actors.get(game.local_id)
	if actor != null and actor.is_seated():
		actor.vehicle_camera.begin(actor.vehicle_ref.get_ref())
		actor.vehicle_camera.orbit_yaw = data.view.x
		actor.vehicle_camera.orbit_pitch = data.view.y
		actor.vehicle_camera.distance = data.view.z
		actor.vehicle_camera.visible_distance = data.view.z
