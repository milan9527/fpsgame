extends RefCounted

var destination := Vector3.INF
var cooldown := 0.0
var trip_time := 0.0
var stopping := false
var approach_point := Vector3.INF
var route := PackedVector3Array()
var route_index := 0
var boarding_departed := false
var boarding_time := 0.0
var boarding_health := 100.0
var boarding_vehicle_health := 600.0

func usable_vehicle(car, actor) -> bool:
	if car.destroyed or not car.grounded or car.fuel < 5 or car.seats.occupant(0) != null or absf(car.speed) > 0.1:
		return false
	var door: Vector3 = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.9
	return actor.position.distance_to(door) <= 12

func early_transport_available(game, actor, goal: Vector3) -> bool:
	if (cooldown > 0 and not approach_point.is_finite()) or actor.health < 50 or actor.heal_left > 0 or actor.shooting or actor.bot_memory_left > 0:
		return false
	for car in game.vehicle_fleet.vehicles.values():
		if usable_vehicle(car, actor):
			if cooldown > 0:
				return true # Preserve an already selected door approach between checks.
			var delta: Vector3 = goal - car.position
			if absf(wrapf(atan2(-delta.x, -delta.z) - car.rotation.y, -PI, PI)) <= 0.5:
				if flat_route(car, goal, actor):
					return true
			elif not turning_route(car, goal, actor).is_empty():
				return true
	cooldown = 0.5
	return false

# A bounded smooth turn from the current heading. Every segment is checked with
# an orientation-independent hull envelope; infantry navigation is not sufficient.
func turning_route(car, end: Vector3, actor) -> PackedVector3Array:
	var result := PackedVector3Array()
	var start: Vector3 = car.position
	var length := start.distance_to(end)
	if length < 25 or length > 100:
		return result
	var forward: Vector3 = -car.global_basis.z
	var direction: Vector3 = (end - start).normalized()
	if forward.dot(direction) < -0.1:
		return result
	var control: Vector3 = start + forward * clampf(length * 0.55, 14, 30)
	var count := ceili(length / 1.5)
	var previous := start
	var shape := BoxShape3D.new()
	var width: float = Vector2(car.BODY_SIZE.x, car.BODY_SIZE.z).length() + 0.8
	shape.size = Vector3(width, car.BODY_SIZE.y, width)
	var space = car.get_world_3d().direct_space_state
	for index in range(1, count + 1):
		var t := float(index) / count
		var point := start.lerp(control, t).lerp(control.lerp(end, t), t)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, previous + Vector3.UP * (car.BODY_SIZE.y / 2 + 0.08))
		query.motion = point - previous
		query.collision_mask = 7
		var excluded: Array[RID] = [car.get_rid(), actor.get_rid()]
		for seat in range(2):
			var occupant = car.seats.occupant(seat)
			if occupant != null and occupant != actor:
				excluded.append(occupant.get_rid())
		query.exclude = excluded
		if not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 0.999:
			return PackedVector3Array()
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < 0.98 or absf(hit.position.y - start.y) > 0.25:
			return PackedVector3Array()
		result.append(point)
		previous = point
	return result

func corridor(car, end: Vector3, actor) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = car.collision_shape.shape
	query.transform = car.global_transform
	query.transform.origin += Vector3.UP * (car.BODY_SIZE.y / 2 + 0.08)
	query.motion = end - car.global_position
	query.motion.y = 0
	query.collision_mask = 7
	var excluded: Array[RID] = [car.get_rid(), actor.get_rid()]
	for index in range(2):
		var occupant = car.seats.occupant(index)
		if occupant != null and occupant != actor:
			excluded.append(occupant.get_rid())
	query.exclude = excluded
	var space = car.get_world_3d().direct_space_state
	return space.intersect_shape(query, 1).is_empty() and space.cast_motion(query)[0] >= 0.999

func flat_route(car, end: Vector3, actor) -> bool:
	if not corridor(car, end, actor):
		return false
	var steps := ceili(car.position.distance_to(end) / 3.0)
	for index in range(steps + 1):
		var point: Vector3 = car.position.lerp(end, float(index) / maxi(1, steps))
		var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1, point - Vector3.UP, 1)
		var floor_hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(ray)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.98 or absf(floor_hit.position.y - car.position.y) > 0.25:
			return false
	return true

func approach(game, actor, goal: Vector3, dt: float, eligible: bool) -> Vector3:
	cooldown = maxf(0, cooldown - dt)
	if not eligible or actor.health < 50 or actor.heal_left > 0:
		approach_point = Vector3.INF
		return goal
	if cooldown > 0:
		return approach_point if approach_point.is_finite() else goal
	approach_point = Vector3.INF
	if actor.position.distance_to(goal) < 25:
		return goal
	# Expensive corridor/ground checks are budgeted per bot, not per physics frame.
	cooldown = 0.5
	for car in game.vehicle_fleet.vehicles.values():
		if not usable_vehicle(car, actor):
			continue
		var door: Vector3 = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.9
		var delta: Vector3 = goal - car.position
		var points := PackedVector3Array()
		if absf(wrapf(atan2(-delta.x, -delta.z) - car.rotation.y, -PI, PI)) <= 0.5:
			if not flat_route(car, goal, actor):
				continue
		else:
			points = turning_route(car, goal, actor)
			if points.is_empty():
				continue
		if car.seats.enter(actor, 0):
			approach_point = Vector3.INF
			destination = goal
			route = points
			route_index = 0
			trip_time = 0
			stopping = false
			boarding_departed = false
			boarding_time = 0.0
			boarding_health = actor.health
			boarding_vehicle_health = car.health
			return actor.position
		approach_point = door
		return door
	return goal

func wait_for_teammate(game, actor, car) -> bool:
	if boarding_departed or game == null or game.match_mode != "duo":
		return false
	if boarding_time >= 3 or absf(car.speed) > 0.1 or car.seats.occupant(1) != null or actor.health < 50 or actor.health < boarding_health or car.health < boarding_vehicle_health:
		boarding_departed = true
		return false
	# Seated bots skip infantry hazard planning. End the optional boarding pause
	# for nearby frag threats to the chassis, while retaining driving collision checks.
	for grenade in game.grenades.values():
		if grenade.kind == 0 and grenade.fuse > 0 and car.position.distance_to(grenade.position) < 9:
			var ray := PhysicsRayQueryParameters3D.create(grenade.position + Vector3.UP * 0.04, car.global_position + Vector3.UP * 0.9, 5, [car.get_rid()])
			ray.hit_from_inside = true
			if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				boarding_departed = true
				return false
	for teammate in game.actors.values():
		if teammate == actor or not teammate.alive or teammate.downed or teammate.is_seated():
			continue
		if game.teams.friendly(actor.actor_id, teammate.actor_id) and car.seats.can_enter(teammate, 1):
			return true
	boarding_departed = true
	return false

func board_teammate(game, actor, eligible: bool) -> bool:
	if not eligible or game.match_mode != "duo" or cooldown > 0 or actor.health < 50 or actor.heal_left > 0:
		return false
	for car in game.vehicle_fleet.vehicles.values():
		var driver = car.seats.occupant(0)
		if driver == null or not driver.alive or driver.downed or not game.teams.friendly(actor.actor_id, driver.actor_id):
			continue
		if car.fuel <= 0 or absf(car.speed) > 0.1:
			continue
		if car.seats.enter(actor, 1):
			approach_point = Vector3.INF
			return true
	return false

func drive(actor, dt: float, game = null) -> void:
	actor.move_input = Vector2.ZERO
	actor.shooting = false
	actor.sprint = false
	var car = actor.vehicle_ref.get_ref()
	if actor.vehicle_seat == 1:
		var driver = car.seats.occupant(0)
		if (driver == null or not driver.alive or driver.downed or car.destroyed or car.fuel <= 0) and absf(car.speed) < 0.1 and car.seats.exit(actor):
			cooldown = 8
		return
	if actor.vehicle_seat != 0 or not actor.alive or actor.downed:
		return
	boarding_time += dt
	if destination.is_finite() and not stopping and wait_for_teammate(game, actor, car):
		car.command(actor.actor_id, car.input_sequence + 1, 0, 0, true, car.seats.epoch)
		return
	trip_time += dt
	var delta: Vector3 = destination - car.position if destination.is_finite() else Vector3.ZERO
	delta.y = 0
	var distance := delta.length()
	if not route.is_empty():
		while route_index < route.size() - 1 and car.position.distance_to(route[route_index]) < 6:
			route_index += 1
		delta = route[route_index] - car.position
		delta.y = 0
	var stopping_distance: float = car.speed * car.speed / (2 * car.BRAKING) + 4
	var probe_end: Vector3 = car.position - car.global_basis.z * maxf(4, stopping_distance)
	stopping = stopping or distance <= stopping_distance or trip_time > 20 or car.fuel <= 0 or car.destroyed or not corridor(car, probe_end, actor)
	var error := 0.0 if distance < 0.001 else wrapf(atan2(-delta.x, -delta.z) - car.rotation.y, -PI, PI)
	stopping = stopping or absf(error) > 1.1
	var target_speed := 12.0 if route.is_empty() else 6.0
	car.command(actor.actor_id, car.input_sequence + 1, 1.0 if not stopping and car.speed < target_speed else 0.0,
		0.0 if stopping else clampf(-error * 1.8, -1, 1), stopping, car.seats.epoch)
	if stopping and absf(car.speed) < 0.1 and car.seats.exit(actor):
		cooldown = 8
		destination = Vector3.INF
		route.clear()
