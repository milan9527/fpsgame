extends RefCounted

const CORNER_SIGNS := [-1.0, 1.0]

var route: Array[Vector3] = []
var route_nodes: Array[Vector3] = []
var route_vehicles: Array = []
var route_index := 0
var replan_left := 0.0
var navigation_target := Vector3.INF
var plans := 0
var active := false
var capsule := CapsuleShape3D.new()
var shape_query := PhysicsShapeQueryParameters3D.new()
var ground_query := PhysicsRayQueryParameters3D.new()
var distances: Array[float] = []
var remaining: Array[float] = []
var previous: Array[int] = []
var visited: Array[bool] = []
var graph_start_cache_enabled := false
var graph_start_clear := -1
var graph_space: PhysicsDirectSpaceState3D
var graph_capsule_offset := -1.0

func _init() -> void:
	ground_query.collision_mask = 1
	capsule.radius = 0.4
	shape_query.shape = capsule
	shape_query.margin = 0.01

func query_at(actor, start: Vector3, end: Vector3, mask: int) -> PhysicsShapeQueryParameters3D:
	# Route graph edges share this shape; update only when body dimensions change.
	# Match the moving body's footprint. An inflated capsule can report an
	# overlap at a valid hull corner and reject every outgoing graph edge,
	# leaving the bot stationary and rebuilding the same failed route.
	var offset := graph_capsule_offset if graph_start_cache_enabled else -1.0
	if offset < 0.0:
		var body_capsule: CapsuleShape3D = actor.body_shape.shape
		var radius: float = body_capsule.radius
		if not is_equal_approx(capsule.radius, radius):
			capsule.radius = radius
		var height := maxf(0.8, body_capsule.height - 0.04)
		if not is_equal_approx(capsule.height, height):
			capsule.height = height
		else:
			height = capsule.height
		offset = height / 2 + 0.04
		# No frame or actor change can occur within a synchronous expansion.
		# Resolve lazily so cost-pruned expansions never read body dimensions.
		if graph_start_cache_enabled:
			# Subsequent queries previously read back the native float height.
			# Preserve that rounding after the first dimension update.
			graph_capsule_offset = capsule.height / 2 + 0.04
	# All callers consume the query synchronously. Keep one per navigator;
	# blocker mutates origin/motion, so reset both on every subsequent query.
	var query := shape_query
	# This capsule is always axis-aligned. Build the transform locally instead
	# of a native transform read/modify/write for every visibility-graph edge.
	query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * offset)
	query.motion = end - start
	query.collision_mask = mask
	return query

func clear_segment(actor, start: Vector3, end: Vector3, mask := 5) -> bool:
	# During one synchronous graph expansion every edge has the same start,
	# capsule and mask. Do not repeat its overlap query for each destination.
	if graph_start_cache_enabled and graph_start_clear == 0:
		return false
	var query := query_at(actor, start, end, mask)
	# An expansion runs synchronously in one physics space. Resolve lazily,
	# since cost pruning can reject all of its edges before any sweep.
	var space: PhysicsDirectSpaceState3D = graph_space if graph_start_cache_enabled else null
	if space == null:
		space = actor.get_world_3d().direct_space_state
		if graph_start_cache_enabled:
			graph_space = space
	# Rejected graph edges need no separate start-overlap query. Sweeps ignore
	# existing overlaps, so clear sweeps must still check the starting capsule.
	if space.cast_motion(query)[0] < 0.999:
		return false
	if graph_start_cache_enabled and graph_start_clear == 1:
		return true
	var start_clear := space.intersect_shape(query, 1).is_empty()
	if graph_start_cache_enabled:
		graph_start_clear = 1 if start_clear else 0
	return start_clear

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
	# Plans run synchronously. Reuse construction buffers as well as the search
	# buffers; never retain vehicle references between plans.
	var nodes := route_nodes
	nodes.clear()
	var actor_position: Vector3 = actor.position
	var obstacle_position: Vector3 = obstacle.global_position
	nodes.append(actor_position)
	nodes.append(destination)
	var vehicles := route_vehicles
	vehicles.clear()
	vehicles.append(obstacle)
	for vehicle in actor.get_tree().get_nodes_in_group("vehicles"):
		if vehicle != obstacle and vehicle.global_position.distance_squared_to(obstacle_position) < 56.25:
			vehicles.append(vehicle)
	# A lone blocking hull is already ordered and within the four-hull cap.
	# Avoid constructing/calling the sort lambda and resizing this common case.
	if vehicles.size() > 1:
		vehicles.sort_custom(func(a, b): return actor_position.distance_squared_to(a.global_position) < actor_position.distance_squared_to(b.global_position))
		vehicles.resize(mini(4, vehicles.size()))
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	# Corner probes run synchronously; reuse parameters across this bot's plans.
	for vehicle in vehicles:
		# No physics step occurs between corner probes. Snapshot once per hull,
		# including its scale and rotation, instead of calling to_global per corner.
		var hull_transform: Transform3D = vehicle.global_transform
		var half_width: float = vehicle.BODY_SIZE.x / 2 + 0.75
		var half_length: float = vehicle.BODY_SIZE.z / 2 + 0.75
		for x in CORNER_SIGNS:
			for z in CORNER_SIGNS:
				var point: Vector3 = hull_transform * Vector3(x * half_width, 0, z * half_length)
				if absf(point.x) > 114.4 or absf(point.z) > 114.4:
					continue
				ground_query.from = point + Vector3.UP
				ground_query.to = point - Vector3.UP
				var ground := space.intersect_ray(ground_query)
				if ground.is_empty() or ground.normal.dot(Vector3.UP) < 0.82 or absf(ground.position.y - actor_position.y) > 0.35:
					continue
				point.y = ground.position.y + 0.02
				var projected: Vector3 = world.navigation_point(point)
				if Vector2(projected.x - point.x, projected.z - point.z).length_squared() > 0.35 * 0.35:
					continue
				nodes.append(point)
	solve_route(actor, nodes)
	vehicles.clear()

func solve_route(actor, nodes: Array[Vector3]) -> void:
	# A small visibility graph chooses a physically clear route around nearby
	# hull corners, including adjacent vehicles and static walls. Euclidean
	# distance is a consistent lower bound on remaining path length, so A*
	# preserves the shortest route while avoiding irrelevant collision probes.
	# Searches are synchronous. Reuse this navigator's buffers, resetting even
	# after an unreachable search and resizing when nearby vehicles change.
	var node_count := nodes.size()
	if distances.size() != node_count:
		distances.resize(node_count)
		remaining.resize(node_count)
		previous.resize(node_count)
		visited.resize(node_count)
	distances.fill(INF)
	previous.fill(-1)
	visited.fill(false)
	# Integer iteration preserves index order without allocating a range array.
	var target_point := nodes[1]
	for index in node_count:
		remaining[index] = nodes[index].distance_to(target_point)
	distances[0] = 0
	# Only a successful goal relaxation changes this bound. Keep it local
	# instead of re-reading the goal and rounding margin for every edge.
	var has_goal_bound := false
	var goal_bound := INF
	for _iteration in nodes:
		var best := -1
		var best_score := INF
		for index in node_count:
			if visited[index]:
				continue
			# The incumbent cannot change during this scan except here.
			# Retain its score instead of re-reading two arrays and adding
			# them for every remaining hull corner. Strict < preserves ties.
			var score := distances[index] + remaining[index]
			if best < 0 or score < best_score:
				best = index
				best_score = score
		if best < 0 or not is_finite(distances[best]):
			return
		if best == 1:
			var at := 1
			while at != 0:
				# Backtrack in append order, avoiding repeated shifts of all
				# stored waypoints, then restore start-to-destination order.
				route.append(nodes[at])
				at = previous[at]
			route.reverse()
			return
		visited[best] = true
		graph_start_cache_enabled = true
		graph_start_clear = -1
		graph_space = null
		graph_capsule_offset = -1.0
		var best_distance := distances[best]
		# The expansion origin is fixed for all outgoing edges. Read the
		# typed-array values once, including the target-edge heuristic.
		var start_point := nodes[best]
		var target_edge_distance := remaining[best]
		for index in node_count:
			# Edge lengths are nonnegative. An equal or cheaper known arrival
			# cannot improve through this node; avoid its distance/sqrt work.
			if visited[index] or distances[index] <= best_distance:
				continue
			# The target edge is exactly the heuristic already computed for
			# this node. Reuse it instead of repeating its vector length.
			var end_point := nodes[index]
			var edge_distance: float = target_edge_distance if index == 1 else start_point.distance_to(end_point)
			var cost := best_distance + edge_distance
			# Once a clear route reaches the goal, edges whose lower bound is
			# longer cannot improve it. Skip their synchronous physics queries.
			# Leave a small margin for floating-point distance rounding.
			if has_goal_bound and cost + remaining[index] > goal_bound:
				continue
			if cost < distances[index] and clear_segment(actor, start_point, end_point):
				distances[index] = cost
				previous[index] = best
				if index == 1:
					has_goal_bound = is_finite(cost)
					goal_bound = cost + 0.0001
			# An overlapping start blocks every outgoing edge from this node.
			# Avoid calculating costs for the remaining edges once confirmed.
			if graph_start_clear == 0:
				break
		# Never retain physics results across expansions, replans or frames.
		graph_start_cache_enabled = false
		graph_start_clear = -1
		graph_space = null
		graph_capsule_offset = -1.0

func steer(actor, world, target: Vector3, dt: float) -> Dictionary:
	replan_left -= dt
	# Collision probes and route planning are synchronous and do not move the
	# actor. Reuse one native position read, including when skipping waypoints.
	var actor_position: Vector3 = actor.position
	var offset: Vector3 = target - actor_position
	offset.y = 0
	var target_distance := offset.length()
	var direction := offset / target_distance if target_distance > 0.0 else Vector3.ZERO
	var obstacle = blocker(actor, actor_position + direction * minf(6, target_distance))
	if obstacle == null:
		active = false
		route.clear()
		return {"blocked": false, "direction": direction}
	active = true
	var should_replan := replan_left <= 0 or target.distance_squared_to(navigation_target) > 1
	while route_index < route.size() and actor_position.distance_squared_to(route[route_index]) < 0.0625:
		route_index += 1
	# A moving obstruction can invalidate an edge immediately after a plan.
	# Stop using that edge, but retain the retry budget: rebuilding the entire
	# visibility graph every physics tick can multiply work across all bots.
	# A synchronous rebuild clears the old route and collision-checks its new
	# edges. Only validate the retained edge when we will actually reuse it.
	if not should_replan and route_index < route.size() and not clear_segment(actor, actor_position, route[route_index]):
		route.clear()
		route_index = 0
	if should_replan:
		navigation_target = target
		replan_left = 0.5
		build_route(actor, world, obstacle, actor_position + direction * minf(20, target_distance))
	if route_index >= route.size():
		return {"blocked": true, "direction": Vector3.ZERO}
	direction = route[route_index] - actor_position
	direction.y = 0
	return {"blocked": true, "direction": direction.normalized()}
