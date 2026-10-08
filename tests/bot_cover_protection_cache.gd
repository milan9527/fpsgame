extends SceneTree

class WorldProbe:
	extends RefCounted
	func navigation_point(at: Vector3) -> Vector3:
		return at

func make_probe(cached: bool):
	var source := FileAccess.get_file_as_string("res://scripts/bot_cover.gd")
	var start := source.find("func protected(")
	var end := source.find("# Project first", start)
	assert(start >= 0 and end > start)
	source = source.substr(0, start) + """var queries := 0
var blocked: Dictionary = {}
func protected(_world, at: Vector3, _threat: Vector3) -> bool:
	queries += 1
	return blocked.get(at, false)

""" + source.substr(end)
	if not cached:
		var block := "\t\tif not protection.has(candidate.p):\n\t\t\tprotection[candidate.p] = protected(world, candidate.p, threat)\n\t\tif protection[candidate.p]:"
		assert(source.contains(block))
		source = source.replace(block, "\t\tif protected(world, candidate.p, threat):")
	var script := GDScript.new()
	script.source_code = source
	assert(script.reload() == OK)
	return script.new()

func _initialize() -> void:
	var cached = make_probe(true)
	var original = make_probe(false)
	var world := WorldProbe.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 515
	var saved := 0
	var old_offsets: PackedVector3Array = cached.search_offsets
	for trial in range(300):
		var offsets := PackedVector3Array()
		var blocked: Dictionary = {}
		for index in range(36):
			var at := Vector3(rng.randi_range(1, 5), 0, 0)
			offsets.append(at)
			blocked[at] = rng.randf() < 0.5
		# Include fully exposed and fully covered duplicate destinations.
		if trial < 2:
			offsets.fill(Vector3(3, 0, 0))
			blocked = {Vector3(3, 0, 0): trial == 1}
		for probe in [cached, original]:
			probe.search_offsets = offsets
			probe.blocked = blocked
			probe.queries = 0
		var actual: Array = cached.find_candidates({"position": Vector3.ZERO}, world, Vector3(0, 0, -30), Vector2.ZERO, 30)
		var expected: Array = original.find_candidates({"position": Vector3.ZERO}, world, Vector3(0, 0, -30), Vector2.ZERO, 30)
		assert(actual == expected, "Shortlist slots, scores and order must remain identical")
		assert(cached.queries <= original.queries)
		saved += original.queries - cached.queries
		if trial < 2:
			assert(cached.queries == 1)
			assert(actual.size() == (6 if trial == 1 else 0))
	cached.search_offsets = old_offsets
	original.search_offsets = old_offsets
	print("BOT_COVER_PROTECTION_CACHE_PASS cases=300 saved_cover_calls=", saved)
	quit()
