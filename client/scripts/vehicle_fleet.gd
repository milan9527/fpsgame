extends RefCounted

const Vehicle = preload("res://scripts/vehicle.gd")
var vehicles: Dictionary = {}
var next_id := 1

func spawn(parent: Node3D, at: Vector3, heading := 0.0):
	if not at.is_finite() or not is_finite(heading):
		return null
	var vehicle = Vehicle.new()
	vehicle.name = "Vehicle_%d" % next_id
	vehicle.position = at
	vehicle.rotation.y = heading
	parent.add_child(vehicle)
	if parent.has_method("vehicle_wrecked"):
		vehicle.wrecked.connect(parent.vehicle_wrecked.bind(vehicle))
	vehicles[next_id] = vehicle
	next_id += 1
	return vehicle

func clear() -> void:
	for vehicle in vehicles.values():
		if is_instance_valid(vehicle):
			vehicle.seats.clear()
			vehicle.get_parent().remove_child(vehicle)
			vehicle.queue_free()
	vehicles.clear()
	next_id = 1

func candidates(actor) -> Array:
	var choices: Array = []
	for vehicle in vehicles.values():
		if not is_instance_valid(vehicle) or not vehicle.grounded or absf(vehicle.speed) > 2.0:
			continue
		for index in range(2):
			if vehicle.seats.slots[index] != null:
				continue
			var distance: float = actor.global_position.distance_to(vehicle.to_global(vehicle.seats.DOORS[index]))
			if distance <= 2.8 and vehicle.seats.can_enter(actor, index):
				choices.append({"vehicle": vehicle, "seat": index, "distance": distance})
	choices.sort_custom(func(a, b): return a.distance < b.distance)
	return choices

func interact(actor) -> bool:
	if actor.is_seated():
		return actor.vehicle_ref.get_ref().seats.exit(actor)
	for choice in candidates(actor):
		if choice.vehicle.seats.enter(actor, choice.seat):
			return true
	return false

func controls(actor, cmd: Dictionary, live: bool) -> void:
	if not actor.is_seated():
		return
	var vehicle = actor.vehicle_ref.get_ref()
	if not vehicles.values().has(vehicle):
		return
	if not live or not actor.alive or actor.downed:
		if vehicle.driver_id == actor.actor_id:
			vehicle.reset_controls()
		return
	# This path is for local authority only. Network commands require separate
	# session, round, vehicle and epoch validation before they can reach a vehicle.
	if actor.vehicle_seat == 0:
		vehicle.command(actor.actor_id, vehicle.input_sequence + 1, -float(cmd.z), float(cmd.x), cmd.crouch, vehicle.seats.epoch)
	if cmd.loot:
		vehicle.seats.exit(actor)

func step(dt: float, live: bool) -> void:
	for id in vehicles.keys():
		var vehicle = vehicles[id]
		if not is_instance_valid(vehicle):
			vehicles.erase(id)
			continue
		if not live:
			vehicle.reset_controls()
		vehicle.simulate(dt, live)

func blast(game, origin: Vector3, attacker_id: int, radius: float, maximum: float) -> void:
	for vehicle in vehicles.values():
		if not is_instance_valid(vehicle) or vehicle.destroyed:
			continue
		var local_origin: Vector3 = vehicle.to_local(origin)
		var nearest := Vector3(clampf(local_origin.x, -vehicle.BODY_SIZE.x / 2, vehicle.BODY_SIZE.x / 2), clampf(local_origin.y, 0, vehicle.BODY_SIZE.y), clampf(local_origin.z, -vehicle.BODY_SIZE.z / 2, vehicle.BODY_SIZE.z / 2))
		var distance: float = origin.distance_to(vehicle.to_global(nearest))
		if distance >= radius:
			continue
		var center: Vector3 = vehicle.global_position + Vector3.UP * 0.9
		var ray := PhysicsRayQueryParameters3D.create(origin, center, 5, [vehicle.get_rid()])
		ray.hit_from_inside = true
		if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			vehicle.take_damage(maximum * (1.0 - distance / radius), attacker_id)
