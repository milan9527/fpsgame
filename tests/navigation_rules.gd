extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func walk(actor, world, destination: Vector3) -> int:
	actor.navigator = load("res://scripts/bot_navigator.gd").new()
	for tick in range(720):
		await physics_frame
		var direction: Vector3 = actor.navigator.steer(actor, world, destination, 1.0 / 60)
		actor.yaw = 0
		actor.move_input = Vector2(direction.x, direction.z)
		actor.simulate(1.0 / 60)
		var offset: Vector3 = actor.position - destination
		if Vector2(offset.x, offset.z).length() < 0.8:
			return tick
	print("NAVIGATION_FAILED at=", actor.position, " destination=", destination, " path=", actor.navigator.path, " index=", actor.navigator.index)
	return -1

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.volume = 0
	for other in game.actors.values():
		other.position = Vector3(100, 0.1, 70 + other.actor_id)
	for i in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	print("NAVIGATION_MAP polygons=", game.world.navigation_region.navigation_mesh.get_polygon_count(), " active=", NavigationServer3D.map_is_active(game.world.get_world_3d().navigation_map))
	assert(game.world.navigation_ready())
	var polygons: int = game.world.navigation_region.navigation_mesh.get_polygon_count()
	assert(polygons > 100)
	var actor = game.actors[-1]
	actor.position = Vector3(-53, 0.02, -35)
	var destination := Vector3(-40, 0.2, -35)
	var ray := PhysicsRayQueryParameters3D.create(actor.position + Vector3.UP, destination + Vector3.UP, 1)
	assert(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Direct route crosses building wall")
	var enter_ticks: int = await walk(actor, game.world, destination)
	assert(enter_ticks >= 0, "Bot physically enters through doorway")
	assert(actor.navigator.reachable)
	assert(actor.navigator.repaths < 8, "Static route is cached")
	var exit_ticks: int = await walk(actor, game.world, Vector3(-30, 0.02, -35))
	assert(exit_ticks >= 0, "Bot physically exits building around opposite wall")
	# Roof is a disconnected navigation island, not a valid ground route.
	actor.navigator = load("res://scripts/bot_navigator.gd").new()
	actor.navigator.steer(actor, game.world, Vector3(-42, 4.3, -35), 1.0 / 60)
	assert(not actor.navigator.reachable, "Disconnected roof is reported unreachable")
	# LOS acquisition followed by loss of sight retains only the observed point.
	var target = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	target.position = Vector3(0, 0.02, 50)
	actor.bot_think = 0
	game.elapsed = 1
	game.zone = 110
	await physics_frame
	game.bot_input(actor, 1.0 / 60)
	assert(actor.target_id == 1 and actor.shooting)
	var observed: Vector3 = actor.bot_last_seen
	target.position = Vector3(-40, 0.2, -35)
	actor.bot_think = 0
	actor.navigator.repath_left = 0
	await physics_frame
	game.bot_input(actor, 1.0 / 60)
	assert(actor.target_id == 0 and not actor.shooting)
	assert(actor.bot_last_seen == observed and actor.navigator.goal == observed)
	assert(actor.bot_memory_left > 2, "Lost target is searched at last visible position")
	actor.bot_memory_left = 0
	actor.bot_patrol_left = 0
	actor.reserve = 0
	game.loot.clear()
	game.loot[1000] = {"kind": 0, "p": Vector3(5, 0.1, 20)}
	actor.navigator.repath_left = 0
	game.bot_input(actor, 1.0 / 60)
	assert(actor.navigator.goal == Vector3(5, 0.1, 20), "Low ammunition selects nearby supplies")
	game.zone = 10
	actor.navigator.repath_left = 0
	game.bot_input(actor, 1.0 / 60)
	assert(actor.sprint and actor.navigator.goal == Vector3.ZERO, "Safety overrides loot and search")
	print("NAVIGATION_RULES_PASS polygons=", polygons, " bake_ms=", game.world.navigation_bake_ms, " enter_ticks=", enter_ticks, " exit_ticks=", exit_ticks, " disconnected=ok cached=ok los_memory=ok supplies=ok zone=ok")
	game.queue_free()
	await process_frame
	quit()
