extends SceneTree

class WorldProbe:
	extends RefCounted
	func navigation_ready() -> bool:
		return true

func make_probe(cached: bool, bounded: bool = true, suffix_bounded: bool = true):
	var source := FileAccess.get_file_as_string("res://scripts/bot_cover.gd")
	source = source.replace("var candidates := find_candidates(actor, world, threat, center, radius)", "var candidates: Array = test_candidates")
	source = source.replace("world.get_world_3d().navigation_map", "RID()")
	source = source.replace("NavigationServer3D.map_get_path(navigation_map, actor_position, candidate.p, true)", "test_route(candidate.p)")
	if not cached or not bounded or not suffix_bounded:
		var suffix_bound := "\t\t\tvar remaining_limit := length_limit - length\n\t\t\tif current.distance_squared_to(endpoint) > remaining_limit * remaining_limit:\n\t\t\t\tlength = INF\n\t\t\t\tbreak\n"
		assert(source.contains(suffix_bound))
		source = source.replace(suffix_bound, "")
	if not cached or not bounded:
		var bound := "\t\tvar length_limit := minf(best, 18.0) + 0.001\n\t\tif previous.distance_squared_to(endpoint) > length_limit * length_limit:\n\t\t\tcontinue\n"
		assert(source.contains(bound))
		source = source.replace(bound, "")
	if not cached:
		var zero_stop := "\t\t\tif best == 0.0:\n\t\t\t\tbreak\n"
		assert(source.contains(zero_stop))
		source = source.replace(zero_stop, "")
		var block := "\t\tif evaluated.has(candidate.p):\n\t\t\tcontinue\n\t\tevaluated[candidate.p] = true\n\t\tvar route: PackedVector3Array = test_route(candidate.p)"
		assert(source.contains(block))
		source = source.replace("var evaluated: Dictionary = {}", "var routes: Dictionary = {}")
		source = source.replace(block, "\t\tif not routes.has(candidate.p):\n\t\t\troutes[candidate.p] = test_route(candidate.p)\n\t\tvar route: PackedVector3Array = routes[candidate.p]")
	source = source.replace("length += current.distance_to(previous)", "test_segments += 1\n\t\t\tlength += current.distance_to(previous)")
	if not cached:
		# Keep the reference accumulator independent of the waypoint cache.
		source = source.replace("length += current.distance_to(previous)", "length += route[index].distance_to(route[index - 1])")
	source += "\nvar test_candidates: Array = []\nvar test_routes: Dictionary = {}\nvar test_queries := 0\nvar test_segments := 0\nfunc test_route(at: Vector3) -> PackedVector3Array:\n\ttest_queries += 1\n\treturn test_routes[at]\n"
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	return script.new()

func _initialize() -> void:
	var cached = make_probe(true)
	var original = make_probe(false)
	var prior = make_probe(true, false)
	var endpoint_only = make_probe(true, true, false)
	var world := WorldProbe.new()
	var actor := {"position": Vector3.ZERO, "actor_id": 1}
	var rng := RandomNumberGenerator.new()
	rng.seed = 514
	var saved := 0
	var bound_saved := 0
	var suffix_saved := 0
	var queries_saved := 0
	for trial in range(600):
		var candidates: Array = []
		var routes: Dictionary = {}
		for index in range(6):
			var at := Vector3(3 if trial == 0 else rng.randi_range(1, 25), 0, 0)
			candidates.append({"p": at})
			if routes.has(at):
				continue
			match rng.randi_range(0, 9) if trial > 0 else 0:
				0: routes[at] = PackedVector3Array([Vector3.ZERO, at])
				1: routes[at] = PackedVector3Array()
				2: routes[at] = PackedVector3Array([Vector3.ZERO, at + Vector3.UP])
				3: routes[at] = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 20), at])
				4: routes[at] = PackedVector3Array([Vector3.ZERO, Vector3(2, 0, 2), at])
				5: routes[at] = PackedVector3Array([at - Vector3(2, 0, 0), at])
				6: routes[at] = PackedVector3Array([at - Vector3(18.00001, 0, 0), at])
				7: routes[at] = PackedVector3Array([at - Vector3(17.99999, 0, 0), at])
				8: routes[at] = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 9), Vector3(0, 0, 8), Vector3(0, 0, 7), Vector3(0, 0, 6), Vector3(0, 0, 5), at])
				9: routes[at] = PackedVector3Array([at])
		for probe in [cached, original, prior, endpoint_only]:
			probe.clear()
			probe.search_left = 0
			probe.test_queries = 0
			probe.test_segments = 0
			probe.test_candidates = candidates
			probe.test_routes = routes
		var actual: Vector3 = cached.select(actor, world, Vector3(0, 0, -20), Vector2.ZERO, 30, true, true, 0)
		var expected: Vector3 = original.select(actor, world, Vector3(0, 0, -20), Vector2.ZERO, 30, true, true, 0)
		var previous: Vector3 = prior.select(actor, world, Vector3(0, 0, -20), Vector2.ZERO, 30, true, true, 0)
		var endpoint_result: Vector3 = endpoint_only.select(actor, world, Vector3(0, 0, -20), Vector2.ZERO, 30, true, true, 0)
		assert(actual == endpoint_result)
		assert(cached.test_queries == endpoint_only.test_queries)
		assert(cached.test_segments <= endpoint_only.test_segments)
		suffix_saved += endpoint_only.test_segments - cached.test_segments
		assert(actual == previous)
		assert(cached.test_queries == prior.test_queries)
		assert(cached.test_segments <= prior.test_segments)
		bound_saved += prior.test_segments - cached.test_segments
		assert(actual == expected)
		assert(cached.hold_left == original.hold_left and cached.last_threat == original.last_threat)
		assert(original.test_queries == routes.size())
		assert(original.test_queries >= cached.test_queries)
		queries_saved += original.test_queries - cached.test_queries
		assert(cached.test_segments <= original.test_segments)
		saved += original.test_segments - cached.test_segments
		if trial == 0:
			assert(cached.test_queries == 1)
			assert(cached.test_segments == 1 and original.test_segments == 6)
	assert(saved > 0)
	assert(bound_saved > 0)
	assert(suffix_saved > 0)
	assert(queries_saved > 0)
	print("BOT_COVER_ROUTE_CACHE_PASS cases=600 duplicate_case_segments=1/6 saved_segments=", saved, " bound_saved_segments=", bound_saved, " suffix_saved_segments=", suffix_saved, " saved_queries=", queries_saved)
	quit()
