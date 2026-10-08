extends SceneTree

# Compare the actual production route loop with its unpruned version on
# detours, threshold lengths and deterministic random paths/threat positions.
func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/bot_hazards.gd")
	var start := source.find("\tfor candidate_index in range(mini(6, candidates.size())):")
	var end := source.find("\n\treturn point", start)
	assert(start >= 0 and end > start)
	var body := source.substr(start, end - start)
	body = body.replace("NavigationServer3D.map_get_path(navigation_map, actor_position, candidate.p, true)", "routes[candidate_index]")
	body = body.replace("var route :=", "var route: PackedVector3Array =")
	body = body.replace("\t\t\t\tvar nearest :=", "\t\t\t\tchecks += 1\n\t\t\t\tvar nearest :=")
	var endpoint_guard := "\t\tif route[0].distance_squared_to(route_end) > 18.001 * 18.001:\n\t\t\tcontinue\n"
	var suffix_guard := "\t\t\tvar remaining_limit := 18.001 - length\n\t\t\tif current.distance_squared_to(route_end) > remaining_limit * remaining_limit:\n\t\t\t\tsafe = false\n\t\t\t\tbreak\n"
	assert(body.contains(endpoint_guard) and body.contains(suffix_guard))
	var optimized = make_probe(body)
	var reference_body := body.replace(endpoint_guard, "").replace(suffix_guard, "")
	reference_body = reference_body.replace("route_end.distance_to(candidate.p)", "route[-1].distance_to(candidate.p)")
	var reference = make_probe(reference_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61220260929
	var saved := 0
	for trial in range(5000):
		var routes: Array = []
		for candidate_index in range(6):
			var route := PackedVector3Array([Vector3.ZERO])
			if trial < 10:
				route.append(Vector3(5, 0, 0))
				route.append(Vector3(18.0 + (trial - 5) * 0.0001, 0, 0))
			elif trial == 10:
				route.append(Vector3(9, 0, 0))
				route.append(Vector3(-9, 0, 0))
			else:
				for segment in range(rng.randi_range(1, 16)):
					route.append(route[-1] + Vector3(rng.randf_range(-6, 6), rng.randf_range(-1, 1), rng.randf_range(-6, 6)))
			routes.append(route)
		var threats: Array = [Vector3(0, 1.2, -30) if trial <= 10 else Vector3(rng.randf_range(-15, 15), 1.2, rng.randf_range(-15, 15))]
		var expected: Vector3 = reference.evaluate(routes, threats)
		var actual: Vector3 = optimized.evaluate(routes, threats)
		assert(actual == expected, "Selected escape differs at trial %d" % trial)
		assert(optimized.checks <= reference.checks)
		saved += reference.checks - optimized.checks
	assert(saved > 0)
	print("BOT_HAZARD_ROUTE_BOUNDS_PASS cases=5000 saved_segment_threat_checks=", saved)
	quit()

func make_probe(body: String):
	var script := GDScript.new()
	script.source_code = """extends RefCounted
var checks := 0
func evaluate(routes: Array, threats: Array) -> Vector3:
	checks = 0
	var point := Vector3.INF
	var planned: Dictionary = {}
	var ids: Array = [1]
	var candidates: Array = []
	for route in routes:
		candidates.append({"p": route[-1]})
	var threat_limits := PackedFloat64Array([minf(9, (Vector3.UP * 1.2).distance_to(threats[0])) - 0.5])
""" + body + "\n\treturn point\n"
	assert(script.reload() == OK)
	return script.new()
