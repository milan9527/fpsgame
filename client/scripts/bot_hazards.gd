extends RefCounted

var point := Vector3.INF
var scan_left := 0.0
var tracked: Array = []
var planned: Dictionary = {}

func clear() -> void:
	point = Vector3.INF
	tracked.clear()
	planned.clear()

func select(game, actor, dt: float) -> Vector3:
	scan_left -= dt
	if scan_left > 0:
		return point
	scan_left = 0.2 + float(absi(actor.actor_id) % 5) * 0.02
	var threats: Array = []
	var ids: Array = []
	for id in game.grenades:
		var grenade = game.grenades[id]
		var reach := 14.0 if id in tracked else 9.0
		if grenade.kind == 0 and grenade.fuse > 0 and actor.position.distance_to(grenade.position) < reach and game.explosion_exposure(grenade.position, actor) > 0:
			threats.append(grenade.position)
			ids.append(id)
	var changed := ids != tracked
	for index in range(ids.size()):
		if not planned.has(ids[index]) or planned[ids[index]].distance_to(threats[index]) > 1.5:
			changed = true
	tracked = ids
	if threats.is_empty() or not game.world.navigation_ready():
		point = Vector3.INF
		planned.clear()
		return point
	var limit: float = maxf(maxf(0, game.zone - 1), Vector2(actor.position.x, actor.position.z).distance_to(game.zone_center))
	if not changed and point.is_finite() and clearance(point, threats) >= 10 and Vector2(point.x, point.z).distance_to(game.zone_center) <= limit:
		return point
	point = Vector3.INF
	var candidates: Array = []
	for radius in [6.0, 10.0]:
		for index in range(12):
			var angle := index * TAU / 12
			var desired: Vector3 = actor.position + Vector3(cos(angle), 0, sin(angle)) * radius
			var at: Vector3 = game.world.navigation_point(desired)
			if at.distance_to(desired) > 1.5 or absf(at.y - actor.position.y) > 1.5:
				continue
			if Vector2(at.x, at.z).distance_to(game.zone_center) > limit:
				continue
			var margin := clearance(at, threats)
			if margin <= clearance(actor.position, threats) + 0.5:
				continue
			candidates.append({"p": at, "score": minf(11, margin) - actor.position.distance_to(at) * 0.12})
	candidates.sort_custom(func(a, b): return a.score > b.score)
	for candidate in candidates.slice(0, mini(6, candidates.size())):
		var route := NavigationServer3D.map_get_path(game.world.get_world_3d().navigation_map, actor.position, candidate.p, true)
		if route.is_empty() or route[-1].distance_to(candidate.p) > 0.8:
			continue
		var length := 0.0
		var safe := true
		for index in range(1, route.size()):
			length += route[index - 1].distance_to(route[index])
			for threat in threats:
				var nearest := Geometry3D.get_closest_point_to_segment(threat, route[index - 1] + Vector3.UP * 1.2, route[index] + Vector3.UP * 1.2)
				if nearest.distance_to(threat) < minf(9, (actor.position + Vector3.UP * 1.2).distance_to(threat)) - 0.5:
					safe = false
		if safe and length <= 18:
			point = candidate.p
			planned.clear()
			for index in range(ids.size()):
				planned[ids[index]] = threats[index]
			break
	return point

func clearance(at: Vector3, threats: Array) -> float:
	var margin := INF
	for threat in threats:
		margin = minf(margin, (at + Vector3.UP * 1.2).distance_to(threat))
	return margin
