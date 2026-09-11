extends SceneTree

class DrivingServer:
	extends "res://scripts/game.gd"
	var test_car
	var driver
	var passenger
	var stage := 0
	var test_elapsed := 0.0
	var done_elapsed := 0.0
	var departure := OS.get_environment("VEHICLE_DEPARTURE")
	var driver_peer := 0
	var departure_at := 0.0
	func reset_round() -> void:
		super.reset_round()
		phase_time = 8
	func begin_round() -> void:
		assert(sessions.size() == 2, "Two backend-authenticated clients required")
		super.begin_round()
		var ids: Array = sessions.keys()
		ids.sort()
		driver = actors[ids[0]]
		driver_peer = ids[0]
		passenger = actors[ids[1]]
		for actor in actors.values():
			actor.position = Vector3(95, 0.1, 90 + abs(actor.actor_id) % 12)
		driver.position = Vector3(-1.65, 0.04, 0.1)
		passenger.position = Vector3(1.65, 0.04, 0.1)
		test_car = vehicle_fleet.spawn(self, Vector3(0, 0.04, 0))
		vehicle_fleet.map_spawned = true
		events = ["VEHICLE_ENTER"]
	func bot_input(actor, _dt: float) -> void:
		actor.move_input = Vector2.ZERO
		actor.shooting = false
	func revoke_account_peer(id: int) -> void:
		super.revoke_account_peer(id)
		if id == driver_peer:
			assert(test_car.throttle == 0 and test_car.input_age >= test_car.INPUT_TIMEOUT)
			print("VEHICLE_REVOCATION_INPUT_CLEARED")
	func _physics_process(dt: float) -> void:
		super._physics_process(dt)
		if stage == 4:
			done_elapsed += dt
			if done_elapsed > 2:
				request_quit()
			return
		if test_car == null:
			return
		test_elapsed += dt
		assert(test_elapsed < 45, "Authenticated driving did not complete")
		if stage == 0 and driver.is_seated() and passenger.is_seated():
			assert(driver.vehicle_seat == 0 and passenger.vehicle_seat == 1)
			stage = 1
			events = ["VEHICLE_DRIVE"]
		elif stage == 1 and test_car.position.z < -8:
			assert(test_car.speed > 8 and test_car.fuel < 100)
			assert(test_car.driver_id == driver.actor_id)
			if departure.is_empty():
				stage = 2
				events = ["VEHICLE_BRAKE"]
			else:
				stage = 5
				departure_at = test_elapsed
				events = ["VEHICLE_DEPARTURE"]
				print("VEHICLE_DEPARTURE_READY uid=" + driver.user_id)
		elif stage == 5:
			events = ["VEHICLE_DEPARTURE"]
			assert(test_elapsed - departure_at < 15, "Driver session was not released")
			if departure == "drop" and test_elapsed - departure_at > 2:
				assert(absf(test_car.speed) < 0.01, "Lost input must brake before ENet disconnect detection")
			if not sessions.has(driver_peer):
				assert(test_car.driver_id == 0 and test_car.seats.occupant(0) == null)
				assert(passenger.is_seated() and passenger.vehicle_seat == 1)
				stage = 6
		elif stage == 6:
			events = ["VEHICLE_DEPARTURE"]
			assert(test_car.driver_id == 0 and passenger.is_seated())
			if absf(test_car.speed) < 0.01:
				stage = 3
				events = ["VEHICLE_EXIT"]
				print("VEHICLE_DEPARTURE_RELEASED driver=0 seat=empty passenger=secured stopped=ok")
		elif stage == 2 and absf(test_car.speed) < 0.01:
			stage = 3
			events = ["VEHICLE_EXIT"]
		elif stage == 3 and (not departure.is_empty() or not driver.is_seated()) and not passenger.is_seated():
			assert(passenger.collision_mask == 7 and test_car.health == 600 and passenger.health == 100)
			if departure.is_empty():
				assert(driver.collision_mask == 7 and driver.health == 100)
			stage = 4
			events = ["VEHICLE_DONE"]
			print("VEHICLE_LOGIN_SERVER_PASS admitted=2 seats=ok acceleration=ok fuel=ok brake=ok exits=ok")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = DrivingServer.new()
	game.name = "Game"
	root.add_child(game)
