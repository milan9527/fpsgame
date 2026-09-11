extends SceneTree
var game
var actor
var maximum_side := 0.0

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func walk(destination: Vector3, frames := 420) -> bool:
	maximum_side = 0
	for _step in range(frames):
		var direction: Vector3 = actor.navigator.steer(actor, game.world, destination, 1.0 / 60)
		assert(not actor.jump_requested, "Vehicle detours must not repeatedly jump into hulls")
		actor.yaw = 0
		actor.move_input = Vector2(direction.x, direction.z)
		actor.simulate(1.0 / 60)
		maximum_side = maxf(maximum_side, absf(actor.position.x))
		if Vector2(actor.position.x - destination.x, actor.position.z - destination.z).length() < 0.8:
			return true
		await physics_frame
	print("DETOUR_FAILED position=", actor.position, " route=", actor.navigator.vehicle_avoidance.route, " plans=", actor.navigator.vehicle_avoidance.plans, " target=", actor.navigator.vehicle_avoidance.navigation_target, " path=", actor.navigator.path)
	return false

func reset_actor(at := Vector3(0, 0.02, 6)) -> void:
	actor.position = at
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	actor.navigator = load("res://scripts/bot_navigator.gd").new()

func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	for other in game.actors.values():
		other.position = Vector3(90, 1, 90 + other.actor_id)
	actor = game.actors[-1]
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	reset_actor()
	await sync_physics()
	assert(await walk(Vector3(0, 0.02, -8)))
	assert(maximum_side > 1.5 and actor.navigator.vehicle_avoidance.plans > 0)
	# A wall on one side forces the physically clear side of the hull.
	var wall = game.world.block(Vector3(2.4, 1.5, 0), Vector3(0.3, 3, 7), "465a61")
	reset_actor()
	await sync_physics()
	assert(await walk(Vector3(0, 0.02, -8)))
	assert(maximum_side > 1.5)
	wall.queue_free()
	# Nose-to-tail vehicles require corners from both hulls.
	var second = game.vehicle_fleet.spawn(game, Vector3(0, 0, -4.5))
	reset_actor()
	await sync_physics()
	assert(await walk(Vector3(0, 0.02, -10)))
	second.queue_free()
	game.vehicle_fleet.vehicles.erase(second.vehicle_id)
	# Rotated wrecks remain obstacles after their engine is disabled.
	car.rotation.y = 0.6
	car.take_damage(1000)
	reset_actor()
	await sync_physics()
	assert(await walk(Vector3(0, 0.02, -8)))
	# When a vehicle moves away, abandon the detour immediately.
	car.rotation.y = 0
	reset_actor()
	await sync_physics()
	var direction: Vector3 = actor.navigator.steer(actor, game.world, Vector3(0, 0.02, -8), 1.0 / 60)
	assert(actor.navigator.vehicle_avoidance.active)
	car.position.x = 12
	await sync_physics()
	direction = actor.navigator.steer(actor, game.world, Vector3(0, 0.02, -8), 1.0 / 60)
	assert(not actor.navigator.vehicle_avoidance.active and absf(direction.x) < 0.01)
	# No valid side corridor: wait and replan instead of clipping through walls.
	car.position.x = 0
	var left = game.world.block(Vector3(-2.2, 1.5, 0), Vector3(0.3, 3, 12), "465a61")
	var right = game.world.block(Vector3(2.2, 1.5, 0), Vector3(0.3, 3, 12), "465a61")
	reset_actor()
	await sync_physics()
	for _step in range(120):
		direction = actor.navigator.steer(actor, game.world, Vector3(0, 0.02, -8), 1.0 / 60)
		assert(direction.is_zero_approx() and not actor.jump_requested)
	assert(actor.navigator.vehicle_avoidance.plans < 6, "Blocked-route graph work is rate-limited")
	left.queue_free()
	right.queue_free()
	await sync_physics()
	assert(await walk(Vector3(0, 0.02, -8)))
	game.running = false
	game.queue_free()
	await process_frame
	print("BOT_VEHICLE_AVOIDANCE_PASS hull=ok wall_side=ok adjacent_vehicles=ok rotated_wreck=ok moving_obstacle=ok blocked_wait=ok recovery=ok no_jump=ok bounded_replans=ok")
	quit()
