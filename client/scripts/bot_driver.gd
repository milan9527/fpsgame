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
# Per-driver scratch resources. Scans are synchronous and still read live physics.
var turn_shape := BoxShape3D.new()
var turn_query := PhysicsShapeQueryParameters3D.new()
var corridor_query := PhysicsShapeQueryParameters3D.new()
var ground_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
var boarding_threat_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 5)

func usable_vehicle(car, actor) -> bool:
	if car.destroyed or not car.grounded or car.fuel < 5 or car.seats.occupant(0) != null or absf(car.speed) > 0.1:
		return false
	var door: Vector3 = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.9
	return actor.position.distance_squared_to(door) <= 144

func early_transport_available(game, actor, goal: Vector3) -> bool:
	if (cooldown > 0 and not approach_point.is_finite()) or actor.health < 50 or actor.heal_left > 0 or actor.shooting or actor.bot_memory_left > 0:
		return false
	# These synchronous queries do not mutate the fleet; avoid copying its values.
	for vehicle_id in game.vehicle_fleet.vehicles:
		var car = game.vehicle_fleet.vehicles[vehicle_id]
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
	var shape := turn_shape
	var width: float = Vector2(car.BODY_SIZE.x, car.BODY_SIZE.z).length() + 0.8
	var hull_size := Vector3(width, car.BODY_SIZE.y, width)
	# Repeated scans share this hull. Avoid invalidating the physics resource
	# unless the next vehicle actually needs different dimensions.
	if shape.size != hull_size:
		shape.size = hull_size
	var space = car.get_world_3d().direct_space_state
	# The hull and occupants stay fixed during this synchronous route scan.
	# Reuse parameters, while still querying live physics at every sample.
	var query := turn_query
	query.shape = shape
	query.collision_mask = 7
	var excluded: Array[RID] = [car.get_rid(), actor.get_rid()]
	for seat in range(2):
		var occupant = car.seats.occupant(seat)
		if occupant != null and occupant != actor:
			excluded.append(occupant.get_rid())
	query.exclude = excluded
	var ray := ground_ray
	# The sample count and hull offset are fixed for this synchronous scan.
	# Allocate the packed output once; failed scans still return an empty route.
	result.resize(count)
	var hull_offset: Vector3 = Vector3.UP * (car.BODY_SIZE.y / 2 + 0.08)
	for index in range(1, count + 1):
		var t := float(index) / count
		var point := start.lerp(control, t).lerp(control.lerp(end, t), t)
		query.transform = Transform3D(Basis.IDENTITY, previous + hull_offset)
		query.motion = point - previous
		if not space.intersect_shape(query, 1).is_empty() or space.cast_motion(query)[0] < 0.999:
			return PackedVector3Array()
		ray.from = point + Vector3.UP
		ray.to = point - Vector3.UP
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < 0.98 or absf(hit.position.y - start.y) > 0.25:
			return PackedVector3Array()
		result[index - 1] = point
		previous = point
	return result

func corridor(car, end: Vector3, actor) -> bool:
	var query := corridor_query
	query.shape = car.collision_shape.shape
	# Assemble value types locally: nested query-property edits otherwise read
	# and write native parameters repeatedly on every driving collision probe.
	var hull_transform: Transform3D = car.global_transform
	var motion: Vector3 = end - hull_transform.origin
	hull_transform.origin += Vector3.UP * (car.BODY_SIZE.y / 2 + 0.08)
	motion.y = 0
	query.transform = hull_transform
	query.motion = motion
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
	# The synchronous scan cannot move the car. Read its native transform once
	# instead of twice for each ground sample along the route.
	var start: Vector3 = car.position
	var steps := ceili(start.distance_to(end) / 3.0)
	var space = car.get_world_3d().direct_space_state
	var ray := ground_ray
	for index in range(steps + 1):
		var point: Vector3 = start.lerp(end, float(index) / maxi(1, steps))
		ray.from = point + Vector3.UP
		ray.to = point - Vector3.UP
		var floor_hit: Dictionary = space.intersect_ray(ray)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.98 or absf(floor_hit.position.y - start.y) > 0.25:
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
	if actor.position.distance_squared_to(goal) < 625:
		return goal
	# Expensive corridor/ground checks are budgeted per bot, not per physics frame.
	cooldown = 0.5
	for vehicle_id in game.vehicle_fleet.vehicles:
		var car = game.vehicle_fleet.vehicles[vehicle_id]
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
	var threat_space: PhysicsDirectSpaceState3D
	for grenade_id in game.grenades:
		var grenade = game.grenades[grenade_id]
		if grenade.kind == 0 and grenade.fuse > 0 and car.position.distance_squared_to(grenade.position) < 81:
			var ray := boarding_threat_ray
			if threat_space == null:
				threat_space = game.get_world_3d().direct_space_state
				ray.to = car.global_position + Vector3.UP * 0.9
				ray.exclude = [car.get_rid()]
				ray.hit_from_inside = true
			ray.from = grenade.position + Vector3.UP * 0.04
			if threat_space.intersect_ray(ray).is_empty():
				boarding_departed = true
				return false
	for teammate_id in game.actors:
		var teammate = game.actors[teammate_id]
		if teammate == actor or not teammate.alive or teammate.downed or teammate.is_seated():
			continue
		if game.teams.friendly(actor.actor_id, teammate.actor_id) and car.seats.can_enter(teammate, 1):
			return true
	boarding_departed = true
	return false

func board_teammate(game, actor, eligible: bool) -> bool:
	if not eligible or game.match_mode != "duo" or cooldown > 0 or actor.health < 50 or actor.heal_left > 0:
		return false
	for vehicle_id in game.vehicle_fleet.vehicles:
		var car = game.vehicle_fleet.vehicles[vehicle_id]
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
		while route_index < route.size() - 1 and car.position.distance_squared_to(route[route_index]) < 36:
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
