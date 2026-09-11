extends RefCounted

var route: Array[Vector3] = []
var route_index := 0
var replan_left := 0.0
var navigation_target := Vector3.INF
var plans := 0
var active := false
var capsule := CapsuleShape3D.new()

func query_at(actor, start: Vector3, end: Vector3, mask: int) -> PhysicsShapeQueryParameters3D:
	capsule.radius = 0.4
	capsule.height = maxf(0.8, actor.body_shape.shape.height - 0.04)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = start + Vector3.UP * (capsule.height / 2 + 0.04)
	query.motion = end - start
	query.collision_mask = mask
	query.margin = 0.01
	return query

func clear_segment(actor, start: Vector3, end: Vector3, mask := 5) -> bool:
	var query := query_at(actor, start, end, mask)
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	return space.cast_motion(query)[0] >= 0.999

func point_blocked(actor, point: Vector3) -> bool:
	point.y = actor.position.y
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	return not space.intersect_shape(query_at(actor, point, point, 4), 1).is_empty()

func static_shortcut_clear(actor, point: Vector3) -> bool:
	point.y = actor.position.y
	return clear_segment(actor, actor.position, point, 1)

func blocker(actor, end: Vector3):
	var query := query_at(actor, actor.position, end, 4)
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var overlaps := space.intersect_shape(query, 1)
	if not overlaps.is_empty():
		return overlaps[0].collider
	var fraction := space.cast_motion(query)
	if fraction[0] >= 1:
		return null
	query.transform.origin += query.motion * minf(1, fraction[1] + 0.002)
	query.motion = Vector3.ZERO
	overlaps = space.intersect_shape(query, 1)
	return null if overlaps.is_empty() else overlaps[0].collider

func build_route(actor, world, obstacle, destination: Vector3) -> void:
	plans += 1
	route.clear()
	route_index = 0
	var nodes: Array[Vector3] = [actor.position, destination]
	var vehicles: Array = [obstacle]
	for vehicle in actor.get_tree().get_nodes_in_group("vehicles"):
		if vehicle != obstacle and vehicle.global_position.distance_to(obstacle.global_position) < 7.5:
			vehicles.append(vehicle)
	vehicles.sort_custom(func(a, b): return actor.position.distance_squared_to(a.global_position) < actor.position.distance_squared_to(b.global_position))
	vehicles.resize(mini(4, vehicles.size()))
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	for vehicle in vehicles:
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var point: Vector3 = vehicle.to_global(Vector3(x * (vehicle.BODY_SIZE.x / 2 + 0.75), 0, z * (vehicle.BODY_SIZE.z / 2 + 0.75)))
				if absf(point.x) > 114.4 or absf(point.z) > 114.4:
					continue
				var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP, 1))
				if ground.is_empty() or ground.normal.dot(Vector3.UP) < 0.82 or absf(ground.position.y - actor.position.y) > 0.35:
					continue
				point.y = ground.position.y + 0.02
				var projected: Vector3 = world.navigation_point(point)
				if Vector2(projected.x - point.x, projected.z - point.z).length() > 0.35:
					continue
				nodes.append(point)
	# A small visibility graph chooses a physically clear route around nearby
	# hull corners, including adjacent vehicles and static walls.
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for _node in nodes:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0
	for _iteration in nodes:
		var best := -1
		for index in range(nodes.size()):
			if not visited[index] and (best < 0 or distances[index] < distances[best]):
				best = index
		if best < 0 or not is_finite(distances[best]):
			return
		if best == 1:
			var at := 1
			while at != 0:
				route.push_front(nodes[at])
				at = previous[at]
			return
		visited[best] = true
		for index in range(nodes.size()):
			if visited[index]:
				continue
			var cost := distances[best] + nodes[best].distance_to(nodes[index])
			if cost < distances[index] and clear_segment(actor, nodes[best], nodes[index]):
				distances[index] = cost
				previous[index] = best

func steer(actor, world, target: Vector3, dt: float) -> Dictionary:
	replan_left -= dt
	var offset: Vector3 = target - actor.position
	offset.y = 0
	var direction := offset.normalized()
	var obstacle = blocker(actor, actor.position + direction * minf(6, offset.length()))
	if obstacle == null:
		active = false
		route.clear()
		return {"blocked": false, "direction": direction}
	active = true
	while route_index < route.size() and actor.position.distance_to(route[route_index]) < 0.25:
		route_index += 1
	if replan_left <= 0 or target.distance_to(navigation_target) > 1 or (route_index < route.size() and not clear_segment(actor, actor.position, route[route_index])):
		navigation_target = target
		replan_left = 0.5
		build_route(actor, world, obstacle, actor.position + direction * minf(20, offset.length()))
	if route_index >= route.size():
		return {"blocked": true, "direction": Vector3.ZERO}
	direction = route[route_index] - actor.position
	direction.y = 0
	return {"blocked": true, "direction": direction.normalized()}
