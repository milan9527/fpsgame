extends SceneTree

class GraphProbe:
	extends "res://scripts/bot_vehicle_avoidance.gd"
	var nodes: Array[Vector3] = []
	var edges: Dictionary = {}
	var queries := 0

	func clear_segment(_actor, start: Vector3, end: Vector3, _mask := 5) -> bool:
		queries += 1
		return edges.has(Vector2i(nodes.find(start), nodes.find(end)))

func reference(probe: GraphProbe) -> Dictionary:
	var costs := PackedFloat64Array()
	costs.resize(probe.nodes.size())
	costs.fill(INF)
	costs[0] = 0.0
	var pending := range(probe.nodes.size())
	var queries := 0
	while not pending.is_empty():
		var best: int = pending[0]
		for index in pending:
			if costs[index] < costs[best]:
				best = index
		if best == 1 or not is_finite(costs[best]):
			break
		pending.erase(best)
		for index in pending:
			var cost := costs[best] + probe.nodes[best].distance_to(probe.nodes[index])
			if cost < costs[index]:
				queries += 1
				if probe.edges.has(Vector2i(best, index)):
					costs[index] = cost
	return {"cost": costs[1], "queries": queries}

func verify(probe: GraphProbe) -> Dictionary:
	var expected := reference(probe)
	probe.solve_route(null, probe.nodes)
	if not is_finite(expected.cost):
		assert(probe.route.is_empty(), "Unreachable destinations must remain blocked")
		return expected
	assert(not probe.route.is_empty() and probe.route.back() == probe.nodes[1])
	var cost := 0.0
	var start := probe.nodes[0]
	for point in probe.route:
		assert(probe.edges.has(Vector2i(probe.nodes.find(start), probe.nodes.find(point))),
			"Every selected route edge must be clear")
		cost += start.distance_to(point)
		start = point
	assert(absf(cost - expected.cost) < 0.0001, "A* must preserve shortest path length")
	return expected

func _initialize() -> void:
	var focused := GraphProbe.new()
	focused.nodes.assign([Vector3.ZERO, Vector3(20, 0, 0), Vector3(10, 0, 1)])
	for index in range(15):
		focused.nodes.append(Vector3(1 + index * 0.25, 0, 3 + index * 0.3))
	for a in range(focused.nodes.size()):
		for b in range(focused.nodes.size()):
			if a != b and not (a == 0 and b == 1):
				focused.edges[Vector2i(a, b)] = true
	var old := verify(focused)
	assert(focused.queries < old.queries, "Off-route corners should require fewer collision probes")
	print("FOCUSED_QUERIES old=", old.queries, " new=", focused.queries)
	var direct := GraphProbe.new()
	direct.nodes.assign(focused.nodes)
	direct.edges = focused.edges.duplicate()
	direct.edges[Vector2i(0, 1)] = true
	var direct_reference := verify(direct)
	assert(direct.queries == 1, "A clear shortest route should prune longer candidate edges")
	print("INCUMBENT_QUERIES reference=", direct_reference.queries, " new=", direct.queries)
	var rng := RandomNumberGenerator.new()
	rng.seed = 322
	var reused := GraphProbe.new()
	var retained_distances := reused.distances
	var retained_remaining := reused.remaining
	var retained_previous := reused.previous
	var retained_visited := reused.visited
	for scenario in range(250):
		var probe := GraphProbe.new()
		for index in range(18):
			probe.nodes.append(Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)))
		for a in range(18):
			for b in range(a + 1, 18):
				# Include disconnected graphs as well as sparse and dense graphs.
				if scenario % 10 != 0 and rng.randf() < (scenario % 5 + 1) * 0.15:
					probe.edges[Vector2i(a, b)] = true
					probe.edges[Vector2i(b, a)] = true
		verify(probe)
		# Exercise the same navigator repeatedly with changing graph sizes,
		# including unreachable graphs between successful searches.
		reused.route.clear()
		reused.nodes.assign(probe.nodes.slice(0, 2 + scenario % 17))
		reused.edges = probe.edges
		verify(reused)
		assert(is_same(retained_distances, reused.distances))
		assert(is_same(retained_remaining, reused.remaining))
		assert(is_same(retained_previous, reused.previous))
		assert(is_same(retained_visited, reused.visited))
	print("BOT_VEHICLE_ROUTE_SEARCH_PASS scenarios=502 reused_searches=250")
	quit()
