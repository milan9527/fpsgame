extends SceneTree

# Execute the production candidate loop and its unpruned reference against
# identical deterministic projections, including exact zone/projection limits.
class ProbeWorld:
	extends RefCounted
	var center := Vector2.ZERO
	var shift := 0.0
	var queries := 0
	func navigation_point(desired: Vector3) -> Vector3:
		queries += 1
		var direction := Vector3(center.x - desired.x, 0, center.y - desired.z)
		return desired + direction.normalized() * shift

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/bot_hazards.gd")
	var start := source.find("\tvar candidates: Array = []")
	var end := source.find("\tif candidates.is_empty():", start)
	assert(start >= 0 and end > start)
	var body := source.substr(start, end - start)
	var guard := "\t\tif Vector2(desired.x, desired.z).distance_squared_to(game.zone_center) > outer_radius_squared:\n\t\t\tcontinue\n"
	assert(body.contains(guard))
	var clearance_guard := "\t\tif clearance(desired, threats) + 1.501 <= origin_clearance + 0.5:\n\t\t\tcontinue\n"
	assert(body.contains(clearance_guard))
	var optimized = make_probe(body)
	var reference = make_probe(body.replace(guard, "").replace(clearance_guard, ""))
	var zone_only = make_probe(body.replace(clearance_guard, ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = 39420260929
	var old_queries := 0
	var new_queries := 0
	var zone_queries := 0
	var comparisons := 0
	for scenario in range(2000):
		var center := Vector2(rng.randf_range(-500, 500), rng.randf_range(-500, 500))
		var limit := rng.randf_range(0, 100)
		var angle := rng.randf_range(-PI, PI)
		var origin := Vector3(center.x + cos(angle) * limit, 0, center.y + sin(angle) * limit)
		if scenario < 10:
			center = Vector2.ZERO
			limit = 4.5
			origin = Vector3.ZERO
		for shift in [0.0, 1.499, 1.5, 1.501, 2.0]:
			var world := ProbeWorld.new()
			world.center = center
			world.shift = shift
			var game := {"world": world, "zone_center": center}
			var actor := {"position": origin}
			var threats: Array = [origin + Vector3(rng.randf_range(-14, 14), rng.randf_range(-2, 2), rng.randf_range(-14, 14))]
			if scenario % 2 == 0:
				threats.append(origin + Vector3(2, 0.15, -3))
			var expected: Array = reference.candidates(game, actor, threats, limit)
			old_queries += world.queries
			world.queries = 0
			assert(zone_only.candidates(game, actor, threats, limit) == expected)
			zone_queries += world.queries
			world.queries = 0
			var actual: Array = optimized.candidates(game, actor, threats, limit)
			new_queries += world.queries
			assert(actual == expected, "Candidate/order/score mismatch at %d shift %f" % [scenario, shift])
			comparisons += 1
	assert(new_queries < old_queries)
	assert(new_queries < zone_queries)
	print("BOT_HAZARD_PROJECTION_PASS comparisons=%d queries_before=%d zone_only=%d queries_after=%d" % [comparisons, old_queries, zone_queries, new_queries])
	quit()

func make_probe(body: String):
	var script := GDScript.new()
	script.source_code = 'extends "res://scripts/bot_hazards.gd"\nfunc candidates(game, actor, threats: Array, limit: float) -> Array:\n' + body + "\treturn candidates\n"
	assert(script.reload() == OK)
	return script.new()
