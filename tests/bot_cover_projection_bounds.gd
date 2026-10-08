extends SceneTree

class Cover:
	extends "res://scripts/bot_cover.gd"
	func protected(_world, at: Vector3, _threat: Vector3) -> bool:
		return at.x > -7.0

class World:
	extends RefCounted
	var delta := Vector3.ZERO
	var calls := 0
	func navigation_point(desired: Vector3) -> Vector3:
		calls += 1
		return desired + delta

class Actor:
	extends RefCounted
	var position := Vector3.ZERO

# Exhaustive reference preserves the old projection/filter/order sequence.
func reference(cover, actor, world, threat: Vector3, center: Vector2, radius: float) -> Array:
	var candidates: Array = []
	var safe_radius := radius - 2.0
	if safe_radius < 0:
		return candidates
	for offset in cover.search_offsets:
		var desired: Vector3 = actor.position + offset
		var at: Vector3 = world.navigation_point(desired)
		if at.distance_squared_to(desired) > 1.5625 or absf(at.y - actor.position.y) > 0.75:
			continue
		if Vector2(at.x, at.z).distance_squared_to(center) > safe_radius * safe_radius or at.distance_squared_to(threat) < 36:
			continue
		candidates.append({"p": at, "score": actor.position.distance_squared_to(at), "order": candidates.size()})
	candidates.sort_custom(func(a, b): return a.score < b.score if a.score != b.score else a.order < b.order)
	var covered: Array = []
	for candidate in candidates:
		if cover.protected(world, candidate.p, threat):
			covered.append(candidate)
			if covered.size() == 6:
				break
	return covered

func _initialize() -> void:
	var cover := Cover.new()
	var actor := Actor.new()
	var world := World.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 376
	var old_calls := 0
	var new_calls := 0
	for iteration in range(2000):
		actor.position = Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
		# Include exact projection thresholds and small perturbations.
		var distance: float = [0.0, 1.2499, 1.25, 1.2501, 2.0][iteration % 5]
		world.delta = Vector3(cos(iteration), 0, sin(iteration)) * distance
		var threat := Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
		var center := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		var radius := rng.randf_range(1, 30)
		world.calls = 0
		var expected := reference(cover, actor, world, threat, center, radius)
		old_calls += world.calls
		world.calls = 0
		var actual := cover.find_candidates(actor, world, threat, center, radius)
		new_calls += world.calls
		if actual != expected:
			push_error("Projection bounds changed candidates at case %d" % iteration)
			quit(1)
			return
	if new_calls >= old_calls:
		push_error("Expected fewer navigation projections")
		quit(1)
		return
	print("BOT_COVER_PROJECTION_BOUNDS_PASS cases=2000 old_queries=%d new_queries=%d" % [old_calls, new_calls])
	quit()
