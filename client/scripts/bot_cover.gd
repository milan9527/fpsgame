extends RefCounted
# Transient tactical state: recomputed after loading a saved operation.
var point := Vector3.INF
var hold_left := 0.0
var search_left := 0.0
var last_threat := Vector3.INF
# Each navigator owns its cover state; these synchronous casts can reuse one query.
var cover_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 5)
var search_space_cache_enabled := false
var search_space: PhysicsDirectSpaceState3D
# Shared, read-only search pattern; keep radius-major ordering for score ties.
static var search_offsets: PackedVector3Array = _make_search_offsets()

static func _make_search_offsets() -> PackedVector3Array:
	var offsets := PackedVector3Array()
	for distance in [3.0, 6.0, 10.0]:
		for index in range(12):
			var angle := index * TAU / 12.0
			offsets.append(Vector3(cos(angle), 0, sin(angle)) * distance)
	return offsets

func clear() -> void:
	point = Vector3.INF
	hold_left = 0

func protected(world, at: Vector3, threat: Vector3) -> bool:
	# Candidate probes are synchronous in one world. Resolve lazily so an
	# empty shortlist performs no lookup, and release it after this search.
	var space: PhysicsDirectSpaceState3D = search_space if search_space_cache_enabled else null
	if space == null:
		space = world.get_world_3d().direct_space_state
		if search_space_cache_enabled:
			search_space = space
	cover_ray.from = threat + Vector3.UP * 1.6
	# Fixed torso/head probes avoid allocating a height Array per candidate.
	cover_ray.to = at + Vector3.UP
	if space.intersect_ray(cover_ray).is_empty():
		return false
	cover_ray.to = at + Vector3.UP * 1.65
	return not space.intersect_ray(cover_ray).is_empty()

# Project first, then test nearest candidates until the six path slots are filled.
# Explicit search-order ties keep equal-distance choices deterministic.
func find_candidates(actor, world, threat: Vector3, center: Vector2, radius: float) -> Array:
	var candidates: Array = []
	var safe_radius := radius - 2.0
	if safe_radius < 0.0:
		return candidates
	var safe_radius_squared := safe_radius * safe_radius
	var outer_radius := safe_radius + 1.251
	var outer_radius_squared := outer_radius * outer_radius
	var origin: Vector3 = actor.position
	var protection: Dictionary = {}
	var covered: Array = []
	var sorted_count := 0
	search_space_cache_enabled = true
	for offset_index in range(search_offsets.size()):
		# At shell boundaries, probe only candidates provably nearer than
		# every remaining accepted projection. This also remains
		# correct if the search pattern is changed or reordered.
		if offset_index > 0 and offset_index % 12 == 0 and candidates.size() >= 6:
			var remaining_squared := INF
			for remaining_index in range(offset_index, search_offsets.size()):
				remaining_squared = minf(remaining_squared, search_offsets[remaining_index].length_squared())
			# Square root is monotonic: reduce squared lengths first, then
			# take it once instead of once per remaining search offset.
			var remaining_distance := maxf(0.0, sqrt(remaining_squared) - 1.251)
			if sorted_count != candidates.size():
				_sort_candidates(candidates)
				sorted_count = candidates.size()
			covered = _covered_candidates(candidates, protection, world, threat, remaining_distance * remaining_distance)
			if covered.size() == 6:
				break
		var offset := search_offsets[offset_index]
		var desired: Vector3 = origin + offset
		# Accepted projections move at most 1.25 m. Triangle-inequality
		# bounds reject impossible destinations before the navigation query.
		# A 1 mm margin keeps borderline floating-point cases on the old path.
		if Vector2(desired.x, desired.z).distance_squared_to(center) > outer_radius_squared:
			continue
		if desired.distance_squared_to(threat) < 4.749 * 4.749:
			continue
		var at: Vector3 = world.navigation_point(desired)
		if at.distance_squared_to(desired) > 1.5625 or absf(at.y - origin.y) > 0.75:
			continue
		if Vector2(at.x, at.z).distance_squared_to(center) > safe_radius_squared or at.distance_squared_to(threat) < 36:
			continue
		candidates.append({"p": at, "score": origin.distance_squared_to(at), "order": candidates.size()})
	# A full bounded shortlist already is the final nearest-six result.
	# Reuse it instead of sorting and scanning the same candidates again.
	if covered.size() != 6:
		# Rejected outer-shell projections leave the sorted shortlist intact.
		# Only appended candidates invalidate its order during this search.
		if sorted_count != candidates.size():
			_sort_candidates(candidates)
		covered = _covered_candidates(candidates, protection, world, threat)
	search_space_cache_enabled = false
	search_space = null
	return covered

func _sort_candidates(candidates: Array) -> void:
	candidates.sort_custom(func(a, b): return a.score < b.score if a.score != b.score else a.order < b.order)

func _covered_candidates(candidates: Array, protection: Dictionary, world, threat: Vector3, score_limit: float = INF) -> Array:
	var covered: Array = []
	# Projections can coincide on navmesh corners. Both ray results are valid
	# for this synchronous search only; keep duplicate slots and their order.
	for candidate in candidates:
		if candidate.score >= score_limit:
			break
		if not protection.has(candidate.p):
			protection[candidate.p] = protected(world, candidate.p, threat)
		if protection[candidate.p]:
			covered.append(candidate)
			if covered.size() == 6:
				break
	return covered

func select(actor, world, threat: Vector3, center: Vector2, radius: float, needed: bool, known: bool, dt: float) -> Vector3:
	hold_left -= dt
	search_left -= dt
	if not needed or not world.navigation_ready():
		clear()
		return point
	if point.is_finite():
		var safe_radius := radius - 2.0
		if hold_left <= 0 or safe_radius < 0.0 or Vector2(point.x, point.z).distance_squared_to(center) > safe_radius * safe_radius:
			clear()
		elif search_left <= 0:
			search_left = 0.8
			# A moved threat invalidates cover without querying physics.
			if threat.distance_squared_to(last_threat) > 16 or not protected(world, point, threat):
				clear()
		if point.is_finite():
			return point
	if not known or search_left > 0:
		return Vector3.INF
	search_left = 0.8 + float(absi(actor.actor_id) % 5) * 0.07
	var candidates := find_candidates(actor, world, threat, center, radius)
	# No protected destination means no navigation world/map lookup is needed.
	if candidates.is_empty():
		return Vector3.INF
	var best := INF
	var navigation_map: RID = world.get_world_3d().navigation_map
	# Synchronous queries cannot move the actor; read its transform once.
	var actor_position: Vector3 = actor.position
	# Several samples can project onto the same navmesh edge or corner.
	# Queries are synchronous with the same origin/map. A previously evaluated
	# destination cannot improve as best only decreases; skip failed routes too.
	# Retain shortlist order and slots so equal scores behave exactly as before.
	var evaluated: Dictionary = {}
	# Bound expensive path requests; physics cover tests never count other actors.
	for candidate_index in range(mini(6, candidates.size())):
		var candidate = candidates[candidate_index]
		if evaluated.has(candidate.p):
			continue
		evaluated[candidate.p] = true
		var route: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, actor_position, candidate.p, true)
		if route.is_empty():
			continue
		var endpoint := route[-1]
		if endpoint.distance_squared_to(candidate.p) > 0.64:
			continue
		var previous := route[0]
		# Use returned endpoints: navigation may project the actor's origin.
		# Every polyline is at least this long. Leave a numerical margin at
		# the threshold so nearly tied paths retain the segment-by-segment test.
		var length_limit := minf(best, 18.0) + 0.001
		if previous.distance_squared_to(endpoint) > length_limit * length_limit:
			continue
		var length := 0.0
		for index in range(1, route.size()):
			# Read each packed waypoint once; reuse it for the suffix bound
			# and the next segment without changing distance accumulation.
			var current := route[index]
			length += current.distance_to(previous)
			previous = current
			# Remaining segments cannot make a rejected path shorter.
			if length >= best or length > 18:
				break
			# Even a straight remaining suffix cannot rescue this detour.
			# Keep the same margin as the endpoint bound, and explicitly
			# reject rather than treating the partial length as a full path.
			var remaining_limit := length_limit - length
			if current.distance_squared_to(endpoint) > remaining_limit * remaining_limit:
				length = INF
				break
		if length < best and length <= 18:
			best = length
			point = candidate.p
			# Projection can return a single waypoint or coincident points.
			# Zero is the global minimum; strict improvements are impossible.
			if best == 0.0:
				break
	if point.is_finite():
		hold_left = 8
		last_threat = threat
	return point
