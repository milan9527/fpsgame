extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	for other in game.actors.values():
		other.position = Vector3(80, 0.1, 80 + other.actor_id)
	var actor = game.actors[1]
	actor.position = Vector3(-1.65, 0.04, 0.1)
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await physics_frame
	await physics_frame
	for _i in range(5):
		game.vehicle_fleet.step(1.0 / 60, true)
	game.dedicated = true
	var round_id: String = game.match_id
	var walking: Dictionary = game.local_command(actor)
	walking.loot = true
	game.apply_actions(actor, walking)
	assert(not actor.is_seated(), "Legacy action RPC must not bypass explicit vehicle epochs")
	assert(not game.receive_vehicle_interaction(2, round_id, 1, car.vehicle_id, car.seats.epoch, 0))
	assert(not game.receive_vehicle_interaction(1, "old-round", 1, car.vehicle_id, car.seats.epoch, 0))
	assert(not game.receive_vehicle_interaction(1, round_id, 1, car.vehicle_id, car.seats.epoch + 1, 0))
	assert(game.receive_vehicle_interaction(1, round_id, 2, car.vehicle_id, car.seats.epoch, 0))
	var epoch: int = car.seats.epoch
	assert(not game.receive_vehicle_input(2, round_id, car.vehicle_id, epoch, 0, 1, 0, false))
	assert(not game.receive_vehicle_input(1, "old-round", car.vehicle_id, epoch, 0, 1, 0, false))
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id + 1, epoch, 0, 1, 0, false))
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch - 1, 0, 1, 0, false))
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 0, NAN, 0, false))
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 1000, 1, 0, false))
	assert(game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 0, 1, 0, false))
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 0, -1, 0, false))
	assert(car.throttle == 1 and car.input_sequence == 0)
	walking.z = 1
	game.apply_command(actor, walking)
	assert(car.throttle == 1 and car.input_sequence == 0 and actor.is_seated(), "Legacy movement must not drive or exit a vehicle")
	game.sessions[1].revoking = true
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 1, -1, 0, false))
	game.sessions[1].revoking = false
	actor.downed = true
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 1, -1, 0, false))
	actor.downed = false
	actor.command_tokens = 0
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 1, -1, 0, false))
	actor.command_tokens = 60
	for _i in range(30):
		game.vehicle_fleet.step(1.0 / 60, true)
	assert(car.input_age > 0.35 and car.speed < 3, "Lost input must expire rather than continue accelerating")
	assert(game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 1, 0, 0, true))
	for _i in range(30):
		game.vehicle_fleet.step(1.0 / 60, true)
	assert(absf(car.speed) < 0.01)
	assert(not game.receive_vehicle_interaction(1, round_id, 2, car.vehicle_id, epoch, -1))
	assert(not game.receive_vehicle_interaction(1, round_id, 3, car.vehicle_id, epoch - 1, -1))
	assert(game.receive_vehicle_interaction(1, round_id, 4, car.vehicle_id, epoch, -1))
	assert(not actor.is_seated() and actor.collision_mask == 7)
	assert(not game.receive_vehicle_input(1, round_id, car.vehicle_id, epoch, 2, 1, 0, false))
	game.dedicated = false
	game.local_recorded_id = game.match_id
	game.leave()
	game.queue_free()
	await process_frame
	print("VEHICLE_AUTHORITY_PASS session=ok round=ok vehicle=ok epoch=ok sequence=ok finite=ok revocation=ok downed=ok rate_limit=ok timeout=ok safe_exit=ok")
	quit()
