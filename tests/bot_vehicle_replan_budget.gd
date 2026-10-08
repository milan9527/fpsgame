extends SceneTree

class AvoidanceProbe:
	extends "res://scripts/bot_vehicle_avoidance.gd"
	var obstructed := true
	var edge_clear := true
	var edge_queries := 0

	func blocker(_actor, _end: Vector3):
		return self if obstructed else null

	func clear_segment(_actor, _start: Vector3, _end: Vector3, _mask := 5) -> bool:
		edge_queries += 1
		return edge_clear

	func build_route(_actor, _world, _obstacle, destination: Vector3) -> void:
		plans += 1
		route.assign([destination])
		route_index = 0

func _initialize() -> void:
	var actor := Node3D.new()
	var probe := AvoidanceProbe.new()
	var target := Vector3(0, 0, -10)
	var dt := 1.0 / 60.0
	probe.steer(actor, null, target, dt)
	assert(probe.plans == 1)
	probe.edge_clear = false
	for tick in range(20):
		var result: Dictionary = probe.steer(actor, null, target, dt)
		assert(probe.plans == 1, "A blocked edge must respect the retry cooldown")
		assert(result.blocked and result.direction == Vector3.ZERO,
			"An invalid edge must stop movement during the retry cooldown")
	assert(probe.plans == 1, "A blocked edge must not rebuild the graph every tick")
	probe.edge_clear = true
	for tick in range(12):
		probe.steer(actor, null, target, dt)
	assert(probe.plans == 2, "Route planning must resume after the cooldown")
	var queries_before := probe.edge_queries
	var changed: Dictionary = probe.steer(actor, null, target + Vector3(2, 0, 0), dt)
	assert(probe.plans == 3 and changed.direction != Vector3.ZERO,
		"A changed navigation target must still replan immediately")
	assert(probe.edge_queries == queries_before, "Replanning must not collision-check the discarded route")
	probe.replan_left = 0
	probe.steer(actor, null, target + Vector3(2, 0, 0), dt)
	assert(probe.plans == 4 and probe.edge_queries == queries_before,
		"Cooldown expiry must replace the route without checking the discarded edge")
	probe.edge_clear = false
	var stopped: Dictionary = probe.steer(actor, null, target + Vector3(2, 0, 0), dt)
	assert(probe.edge_queries == queries_before + 1 and stopped.direction == Vector3.ZERO,
		"A moving obstacle must invalidate a retained edge immediately")
	probe.obstructed = false
	var cleared: Dictionary = probe.steer(actor, null, target, dt)
	assert(not cleared.blocked and not probe.active and probe.route.is_empty(),
		"A removed vehicle must release avoidance immediately")
	var diagonal: Dictionary = probe.steer(actor, null, Vector3(3, 7, -4), dt)
	assert(diagonal.direction.is_equal_approx(Vector3(0.6, 0, -0.8)),
		"Steering must normalize horizontal distance independently of target height")
	var arrived: Dictionary = probe.steer(actor, null, actor.position, dt)
	assert(arrived.direction == Vector3.ZERO, "A zero-distance target must not divide by zero")
	actor.free()
	print("BOT_VEHICLE_REPLAN_BUDGET_PASS")
	quit()
