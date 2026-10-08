extends SceneTree

class CoverProbe:
	extends "res://scripts/bot_cover.gd"
	var queries := 0
	var sorts := 0
	var blocked: Dictionary = {}
	func _sort_candidates(candidates: Array) -> void:
		sorts += 1
		super._sort_candidates(candidates)
	func protected(_world, at: Vector3, _threat: Vector3) -> bool:
		queries += 1
		return blocked.has(at)

class WorldProbe:
	extends RefCounted
	var projected: Dictionary = {}
	var projections := 0
	func navigation_point(at: Vector3) -> Vector3:
		projections += 1
		return projected.get(at, at)

func _initialize() -> void:
	var probe := CoverProbe.new()
	var world := WorldProbe.new()
	var actor := {"position": Vector3.ZERO}
	var rng := RandomNumberGenerator.new()
	rng.seed = 29728
	var saved := 0
	var default_offsets: PackedVector3Array = probe.search_offsets
	for trial in range(500):
		var offsets := default_offsets.duplicate()
		if trial > 1:
			for index in range(offsets.size() - 1, 0, -1):
				var other := rng.randi_range(0, index)
				var temporary := offsets[index]
				offsets[index] = offsets[other]
				offsets[other] = temporary
		probe.search_offsets = offsets
		probe.blocked.clear()
		world.projected.clear()
		probe.queries = 0
		world.projections = 0
		var threat := Vector3(0, 0, -30 if trial == 0 else -15)
		var radius := rng.randf_range(-2, 30)
		if trial == 0:
			radius = 30
		var expected: Array = []
		var exhaustive_queries := 0
		for offset in probe.search_offsets:
			var at: Vector3 = offset
			if trial > 0:
				at += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			world.projected[offset] = at
			var is_covered := trial == 0 or (trial > 1 and rng.randf() < 0.5)
			if is_covered:
				probe.blocked[at] = true
			if at.distance_squared_to(offset) > 1.5625 or absf(at.y) > 0.75:
				continue
			if Vector2(at.x, at.z).length() > radius - 2 or at.distance_squared_to(threat) < 36:
				continue
			exhaustive_queries += 1
			if is_covered:
				# Independent stable insertion oracle; exhaustive cover evaluation.
				var item := {"p": at, "score": at.length_squared()}
				var index := 0
				while index < expected.size() and expected[index].score <= item.score:
					index += 1
				expected.insert(index, item)
		expected.resize(mini(6, expected.size()))
		var actual := probe.find_candidates(actor, world, threat, Vector2.ZERO, radius)
		assert(actual.size() == expected.size())
		for index in range(actual.size()):
			assert(actual[index].p == expected[index].p)
		assert(probe.queries <= exhaustive_queries)
		saved += exhaustive_queries - probe.queries
		if trial == 0:
			assert(probe.queries == 6 and exhaustive_queries == 36)
			assert(world.projections == 12, "Six nearby covered slots must skip the two distant projection shells")
			print("COVER_DENSE_CASE cover_calls=6 exhaustive_calls=36 projections=12 exhaustive_projections=36")
	probe.search_offsets = default_offsets
	print("BOT_COVER_SHORTLIST_PASS cases=500 shuffled_patterns=498 saved_cover_calls=", saved)
	world.projections = 0
	assert(probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 1.99).is_empty())
	assert(world.projections == 0, "Empty safe zone must skip navigation projection")
	world.projected.clear()
	probe.blocked.clear()
	probe.blocked[Vector3(3, 0, 0)] = true
	for radius in [2.0, 5.0, 8.0, 12.0]:
		var result := probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, radius)
		assert(result.size() == (0 if radius < 5.0 else 1))
		for candidate in result:
			assert(Vector2(candidate.p.x, candidate.p.z).length() <= radius - 2)
	print("COVER_SAFE_RADIUS_PASS empty_zone_projection_calls=0 boundary_cases=4")
	# A far candidate in the first shell must not prevent an early exit
	# once six covered candidates precede every unprojected point.
	var original_offsets: PackedVector3Array = probe.search_offsets
	var reordered := PackedVector3Array()
	for index in range(6):
		reordered.append(original_offsets[index])
		reordered.append(original_offsets[24 + index])
	for index in range(12, 24):
		reordered.append(original_offsets[index])
	probe.search_offsets = reordered
	probe.blocked.clear()
	for offset in reordered:
		probe.blocked[offset] = true
	world.projections = 0
	probe.queries = 0
	var mixed := probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 30)
	assert(mixed.size() == 6)
	for candidate in mixed:
		assert(candidate.score < 10.0)
	assert(world.projections == 12 and probe.queries == 6)
	probe.search_offsets = original_offsets
	print("COVER_MIXED_SHELL_PASS projections=12 exhaustive_projections=24 cover_calls=6")
	# Partial intermediate shortlists must be refreshed after distant shells.
	probe.blocked.clear()
	for index in range(3):
		probe.blocked[original_offsets[index]] = true
		probe.blocked[original_offsets[24 + index]] = true
	world.projections = 0
	probe.queries = 0
	var sparse := probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 30)
	assert(sparse.size() == 6, "Refresh partial nearby results with distant cover")
	var seen := {}
	for candidate in sparse:
		assert(probe.blocked.has(candidate.p))
		seen[candidate.p] = true
	assert(seen.size() == 6 and world.projections == 36)
	print("COVER_SPARSE_SHELL_PASS near=3 distant=3 projections=36")
	probe.blocked.clear()
	world.projections = 0
	probe.queries = 0
	assert(probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 30).is_empty())
	assert(world.projections == 36 and probe.queries == 36)
	print("COVER_EMPTY_AFTER_SPARSE_PASS cover_calls=36 projections=36")
	# Only the inner shell fits. No cover forces every boundary and final
	# scan, but rejected outer shells cannot invalidate the first sort.
	probe.sorts = 0
	assert(probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 5.1).is_empty())
	assert(probe.sorts == 1, "Unchanged candidates must not be sorted again")
	probe.sorts = 0
	assert(probe.find_candidates(actor, world, Vector3(0, 0, -30), Vector2.ZERO, 2).is_empty())
	assert(probe.sorts == 0, "Empty candidates need no sort")
	print("COVER_SORT_REUSE_PASS unchanged_shortlist_sorts=1 empty_sorts=0")
	quit()
