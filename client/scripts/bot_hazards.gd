extends RefCounted

static var search_offsets: Array[Vector3] = _build_search_offsets()

static func _build_search_offsets() -> Array[Vector3]:
	# Shared immutable ring geometry; keep the original order and arithmetic.
	var offsets: Array[Vector3] = []
	for radius in [6.0, 10.0]:
		for index in range(12):
			var angle := index * TAU / 12
			offsets.append(Vector3(cos(angle), 0, sin(angle)) * radius)
	return offsets

var point := Vector3.INF
var scan_left := 0.0
var tracked: Array = []
var planned: Dictionary = {}
var threat_limits := PackedFloat64Array()
var scan_threats: Array = []
var scan_ids: Array = []
var candidate_pool: Array[Dictionary] = []
var candidates: Array[Dictionary] = []

func clear() -> void:
	point = Vector3.INF
	tracked.clear()
	planned.clear()
	scan_threats.clear()
	scan_ids.clear()

func select(game, actor, dt: float) -> Vector3:
	scan_left -= dt
	if scan_left > 0:
		return point
	scan_left = 0.2 + float(absi(actor.actor_id) % 5) * 0.02
	# Most scans have no grenades; release stale routes without allocating
	# temporary threat arrays for every bot.
	if game.grenades.is_empty():
		clear()
		return point
	# Refill per-bot buffers in place. The usual repeated scan with the same
	# threats needs neither new Array containers nor growing their storage.
	# Selection is synchronous: physics cannot move the actor or grenades
	# during this scan. Read native transforms once, including candidate search.
	var actor_position: Vector3 = actor.position
	var threat_count := 0
	for id in game.grenades:
		var grenade = game.grenades[id]
		if grenade.kind != 0 or grenade.fuse <= 0:
			continue
		var grenade_position: Vector3 = grenade.position
		# Neither new nor tracked threats can reach beyond 14m. Reject far
		# projectiles before the tracked-ID search and square root, keeping
		# slack and the original distance test for exact boundary behavior.
		if actor_position.distance_squared_to(grenade_position) > 14.001 * 14.001:
			continue
		var reach := 14.0 if id in tracked else 9.0
		if actor_position.distance_to(grenade_position) < reach and game.explosion_visible(grenade_position, actor):
			if threat_count == scan_threats.size():
				scan_threats.append(grenade_position)
			else:
				scan_threats[threat_count] = grenade_position
			if threat_count == scan_ids.size():
				scan_ids.append(id)
			else:
				scan_ids[threat_count] = id
			threat_count += 1
	scan_threats.resize(threat_count)
	scan_ids.resize(threat_count)
	var threats: Array = scan_threats
	var ids: Array = scan_ids
	var changed := ids != tracked
	# One invalidation already requires a new route; remaining comparisons
	# cannot change that decision.
	if not changed:
		for index in range(ids.size()):
			if not planned.has(ids[index]) or planned[ids[index]].distance_to(threats[index]) > 1.5:
				changed = true
				break
	# Keep last scan's IDs separate for hysteresis and change detection.
	# Reuse the previous tracked buffer for the next scan.
	scan_ids = tracked
	tracked = ids
	if threats.is_empty() or not game.world.navigation_ready():
		point = Vector3.INF
		planned.clear()
		return point
	# The zone cannot advance during this synchronous search. Avoid repeated
	# dynamic property lookups for every projected candidate.
	var zone_center: Vector2 = game.zone_center
	var limit: float = maxf(maxf(0, game.zone - 1), Vector2(actor_position.x, actor_position.z).distance_to(zone_center))
	if not changed and point.is_finite() and clearance(point, threats) >= 10 and Vector2(point.x, point.z).distance_to(zone_center) <= limit:
		return point
	point = Vector3.INF
	candidates.clear()
	# Actor and threats are unchanged throughout this synchronous search.
	var origin_clearance := clearance(actor_position, threats)
	# A valid projection moves at most 1.5m. Points farther outside the zone
	# cannot return to it; allow 1mm slack for floating-point boundaries.
	var outer_radius_squared := (limit + 1.501) * (limit + 1.501)
	for offset in search_offsets:
		var desired: Vector3 = actor_position + offset
		if Vector2(desired.x, desired.z).distance_squared_to(zone_center) > outer_radius_squared:
			continue
		# Projection moves at most 1.5m, so even its best possible clearance
		# cannot rescue this candidate. Keep 1mm slack at the boundary.
		if clearance(desired, threats) + 1.501 <= origin_clearance + 0.5:
			continue
		var at: Vector3 = game.world.navigation_point(desired)
		if at.distance_to(desired) > 1.5 or absf(at.y - actor_position.y) > 1.5:
			continue
		if Vector2(at.x, at.z).distance_to(zone_center) > limit:
			continue
		var margin := clearance(at, threats)
		if margin <= origin_clearance + 0.5:
			continue
		# Sorting only changes the active list. Pool order stays independent,
		# so each accepted candidate gets a distinct reusable dictionary.
		var slot := candidates.size()
		if slot == candidate_pool.size():
			candidate_pool.append({})
		var entry: Dictionary = candidate_pool[slot]
		entry["p"] = at
		entry["score"] = minf(11, margin) - actor_position.distance_to(at) * 0.12
		candidates.append(entry)
	if candidates.is_empty():
		return point
	candidates.sort_custom(func(a, b): return a.score > b.score)
	# These limits depend on the actor's starting position, not the route
	# segment. Reuse them across all six candidate paths.
	# Keep this bot's scratch buffer across synchronous searches. Overwrite
	# every entry so moving grenades never reuse an earlier safety distance.
	if threat_limits.size() != threats.size():
		threat_limits.resize(threats.size())
	var route_origin: Vector3 = actor_position + Vector3.UP * 1.2
	for threat_index in range(threats.size()):
		threat_limits[threat_index] = minf(9, route_origin.distance_to(threats[threat_index])) - 0.5
	var navigation_map: RID = game.world.get_world_3d().navigation_map
	for candidate_index in range(mini(6, candidates.size())):
		var candidate: Dictionary = candidates[candidate_index]
		var route := NavigationServer3D.map_get_path(navigation_map, actor_position, candidate.p, true)
		if route.is_empty():
			continue
		# The path is immutable for this synchronous scan. Reuse its final
		# point for endpoint validation and every suffix length bound.
		var route_end: Vector3 = route[-1]
		if route_end.distance_to(candidate.p) > 0.8:
			continue
		# Returned navigation endpoints bound every possible polyline length.
		# Leave 1 mm for floating-point rounding at the existing 18 m limit.
		if route[0].distance_squared_to(route_end) > 18.001 * 18.001:
			continue
		var length := 0.0
		var safe := true
		# Adjacent segments share an endpoint. Carry its value and elevated
		# sample forward instead of rereading and translating it each time.
		var previous: Vector3 = route[0]
		var segment_start: Vector3 = previous + Vector3.UP * 1.2
		for index in range(1, route.size()):
			var current: Vector3 = route[index]
			length += previous.distance_to(current)
			# Neither added length nor an unsafe segment can be repaired by
			# later segments; avoid checking the rest of a rejected route.
			if length > 18:
				break
			# Even a straight suffix cannot rescue this detour. Reject before
			# testing threats along this segment or any later segment.
			var remaining_limit := 18.001 - length
			if current.distance_squared_to(route_end) > remaining_limit * remaining_limit:
				safe = false
				break
			var segment_end: Vector3 = current + Vector3.UP * 1.2
			for threat_index in range(threats.size()):
				# A nonnegative distance cannot violate this clearance.
				# Close explosions may give zero or negative limits.
				if threat_limits[threat_index] <= 0.0:
					continue
				var threat: Vector3 = threats[threat_index]
				var nearest := Geometry3D.get_closest_point_to_segment(threat, segment_start, segment_end)
				if nearest.distance_to(threat) < threat_limits[threat_index]:
					safe = false
					break
			if not safe:
				break
			previous = current
			segment_start = segment_end
		if safe and length <= 18:
			point = candidate.p
			planned.clear()
			for index in range(ids.size()):
				planned[ids[index]] = threats[index]
			break
	return point

func clearance(at: Vector3, threats: Array) -> float:
	# A single grenade is the common case. There is no nearest-neighbor
	# reduction to perform; retain the original distance and invalid result.
	if threats.size() == 1:
		var distance := (at + Vector3.UP * 1.2).distance_to(threats[0])
		return distance if distance < INF else INF
	# The closest threat also has the smallest squared distance. Only take
	# the square root once, after reducing all threats for this candidate.
	var margin_squared := INF
	var sample := at + Vector3.UP * 1.2
	var nearest := Vector3.INF
	for threat in threats:
		var distance_squared := sample.distance_squared_to(threat)
		if distance_squared < margin_squared:
			margin_squared = distance_squared
			nearest = threat
	# Keep Vector3's distance precision for the callers' strict thresholds.
	return sample.distance_to(nearest) if margin_squared < INF else INF
