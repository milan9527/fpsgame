extends RefCounted
# Transient tactical state: recomputed after loading a saved operation.
var point := Vector3.INF
var hold_left := 0.0
var search_left := 0.0
var last_threat := Vector3.INF

func clear() -> void:
	point = Vector3.INF
	hold_left = 0

func protected(world, at: Vector3, threat: Vector3) -> bool:
	for height in [1.0, 1.65]:
		var ray := PhysicsRayQueryParameters3D.create(threat + Vector3.UP * 1.6, at + Vector3.UP * height, 5)
		if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true

func select(actor, world, threat: Vector3, center: Vector2, radius: float, needed: bool, known: bool, dt: float) -> Vector3:
	hold_left -= dt
	search_left -= dt
	if not needed or not world.navigation_ready():
		clear()
		return point
	if point.is_finite():
		if hold_left <= 0 or Vector2(point.x, point.z).distance_to(center) > radius - 2:
			clear()
		elif search_left <= 0:
			search_left = 0.8
			if not protected(world, point, threat) or threat.distance_to(last_threat) > 4:
				clear()
		if point.is_finite():
			return point
	if not known or search_left > 0:
		return Vector3.INF
	search_left = 0.8 + float(absi(actor.actor_id) % 5) * 0.07
	var candidates: Array = []
	for distance in [3.0, 6.0, 10.0]:
		for index in range(12):
			var angle := index * TAU / 12.0
			var desired: Vector3 = actor.position + Vector3(cos(angle), 0, sin(angle)) * distance
			var at: Vector3 = world.navigation_point(desired)
			if at.distance_to(desired) > 1.25 or absf(at.y - actor.position.y) > 0.75:
				continue
			if Vector2(at.x, at.z).distance_to(center) > radius - 2 or at.distance_to(threat) < 6:
				continue
			if protected(world, at, threat):
				candidates.append({"p": at, "score": actor.position.distance_to(at)})
	candidates.sort_custom(func(a, b): return a.score < b.score)
	var best := INF
	# Bound expensive path requests; physics cover tests never count other actors.
	for candidate in candidates.slice(0, mini(6, candidates.size())):
		var route := NavigationServer3D.map_get_path(world.get_world_3d().navigation_map, actor.position, candidate.p, true)
		if route.is_empty() or route[-1].distance_to(candidate.p) > 0.8:
			continue
		var length := 0.0
		for index in range(1, route.size()):
			length += route[index].distance_to(route[index - 1])
		if length < best and length <= 18:
			best = length
			point = candidate.p
	if point.is_finite():
		hold_left = 8
		last_threat = threat
	return point
