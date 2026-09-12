extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for seat in [0, 1]:
		for yaw in [-1.93, 1.93]:
			if not await check_exit(game, seat, yaw):
				game.request_quit(1)
				return
	if not await check_removed_car(game):
		game.request_quit(1)
		return
	print("VEHICLE_EXIT_MOVEMENT_PASS both_seats=ok rotated_hulls=ok sprint_into_hull=blocked chassis=stable movement_resumes=ok")
	game.request_quit()

func check_exit(game, seat: int, yaw: float) -> bool:
	game.start_solo()
	for other in game.actors.values():
		other.position = Vector3(90, 0.1, 90 + other.actor_id)
	var actor = game.actors[1]
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO, yaw)
	actor.position = car.to_global(car.seats.DOORS[seat]) - Vector3.UP * 0.9
	await physics_frame
	await physics_frame
	for _i in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(actor, seat))
	await physics_frame
	car.simulate(1.0 / 60)
	assert(car.seats.exit(actor))
	var parked: Vector3 = car.position
	var side := -1.0 if seat == 0 else 1.0
	for step in range(20):
		# Include input in the exit frame before the physics-boundary callback.
		actor.move_input = Vector2(-side, 0)
		actor.sprint = true
		actor.move_step(1.0 / 60)
		car.simulate(1.0 / 60)
		var relative: Vector3 = car.to_local(actor.position)
		if relative.x * side < car.BODY_SIZE.x / 2 + 0.38 - 0.03 or car.position.distance_to(parked) > 0.03:
			print("EXIT_MOVEMENT_FAILED seat=", seat, " yaw=", yaw, " step=", step, " local=", relative, " chassis_shift=", car.position.distance_to(parked))
			return false
		await physics_frame
	assert(car.collision_releases.is_empty())
	var before: Vector3 = actor.position
	for _step in range(5):
		await physics_frame
		actor.move_input = Vector2(side, 0)
		actor.move_step(1.0 / 60)
		car.simulate(1.0 / 60)
	assert(actor.position.distance_to(before) > 0.4, "Movement must resume after collision restoration")
	game.local_recorded_id = game.match_id
	game.leave()
	return true


func check_removed_car(game) -> bool:
	game.start_solo()
	for other in game.actors.values():
		other.position = Vector3(90, 0.1, 90 + other.actor_id)
	var actor = game.actors[1]
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	actor.position = Vector3(-1.65, 0.04, 0.1)
	await physics_frame
	await physics_frame
	for _step in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(actor, 0) and car.seats.exit(actor))
	game.vehicle_fleet.vehicles.erase(car.vehicle_id)
	game.remove_child(car) # Keep it alive: weak-reference expiry cannot release the guard.
	var before: Vector3 = actor.position
	for _step in range(5):
		await physics_frame
		actor.sprint = true
		actor.move_input = Vector2.LEFT
		actor.move_step(1.0 / 60)
	var moved: float = actor.position.distance_to(before)
	game.add_child(car)
	var exceptions_remain: bool = car.get_collision_exceptions().has(actor)
	car.queue_free()
	if moved < 0.4 or exceptions_remain:
		print("REMOVED_CAR_EXIT_FAILED moved=", moved, " stale_exception=", exceptions_remain)
		return false
	print("REMOVED_CAR_EXIT_OK movement=restored collision_exception=cleared")
	game.local_recorded_id = game.match_id
	game.leave()
	return true
