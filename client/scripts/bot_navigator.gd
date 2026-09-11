extends RefCounted

var cover = preload("res://scripts/bot_cover.gd").new()
var utilities = preload("res://scripts/bot_utilities.gd").new()
var hazards = preload("res://scripts/bot_hazards.gd").new()
var vehicle_avoidance = preload("res://scripts/bot_vehicle_avoidance.gd").new()

var path := PackedVector3Array()
var index := 0
var goal := Vector3.INF
var repath_left := 0.0
var stuck_time := 0.0
var jump_left := 0.0
var previous_position := Vector3.INF
var finished := true
var reachable := false
var repaths := 0

func steer(actor, world, destination: Vector3, dt: float, goal_tolerance := 1.5) -> Vector3:
	if not world.navigation_ready():
		return Vector3.ZERO
	repath_left -= dt
	jump_left = maxf(0, jump_left - dt)
	if previous_position.is_finite() and not finished:
		var displacement: Vector3 = actor.position - previous_position
		stuck_time = stuck_time + dt if Vector2(displacement.x, displacement.z).length() < 0.012 else 0.0
	previous_position = actor.position
	if repath_left <= 0 and (goal.distance_to(destination) > goal_tolerance or path.is_empty() or stuck_time > 1.2):
		goal = destination
		var projected: Vector3 = world.navigation_point(destination)
		path = NavigationServer3D.map_get_path(world.get_world_3d().navigation_map, actor.position, projected, true)
		index = 0
		repaths += 1
		repath_left = 0.6 + float(absi(actor.actor_id) % 5) * 0.07
		reachable = not path.is_empty() and path[-1].distance_to(projected) < 1
	while index < path.size():
		var offset: Vector3 = path[index] - actor.position
		if Vector2(offset.x, offset.z).length() > 0.55:
			break
		index += 1
	finished = index >= path.size()
	if finished:
		return Vector3.ZERO
	var detour_index := index
	while detour_index + 1 < path.size() and vehicle_avoidance.point_blocked(actor, path[detour_index]) and vehicle_avoidance.static_shortcut_clear(actor, path[detour_index + 1]):
		detour_index += 1
	var was_avoiding: bool = vehicle_avoidance.active
	var avoidance: Dictionary = vehicle_avoidance.steer(actor, world, path[detour_index], dt)
	if avoidance.blocked:
		if not vehicle_avoidance.route.is_empty():
			index = detour_index
		actor.jump_requested = false
		return avoidance.direction
	if was_avoiding:
		stuck_time = 0.0
		if not vehicle_avoidance.static_shortcut_clear(actor, path[index]):
			# Rejoin the static navigation mesh from the detour position; removing
			# a vehicle must not turn a building corner into a direct shortcut.
			path.clear()
			repath_left = 0.0
			return Vector3.ZERO
	# Recover from low floor lips and dynamic body obstruction without repeatedly
	# jumping into arbitrary walls. Route planning itself never ignores walls.
	if stuck_time > 0.4 and jump_left <= 0 and actor.grounded and actor.is_on_wall():
		actor.jump_requested = true
		jump_left = 1.0
	var direction: Vector3 = path[index] - actor.position
	direction.y = 0
	return direction.normalized()
