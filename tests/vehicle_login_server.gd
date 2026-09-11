extends SceneTree

class DrivingServer:
	extends "res://scripts/game.gd"
	var test_car
	var driver
	var passenger
	var stage := 0
	var test_elapsed := 0.0
	var done_elapsed := 0.0
	func reset_round() -> void:
		super.reset_round()
		phase_time = 8
	func begin_round() -> void:
		assert(sessions.size() == 2, "Two backend-authenticated clients required")
		super.begin_round()
		var ids: Array = sessions.keys()
		ids.sort()
		driver = actors[ids[0]]
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
			stage = 2
			events = ["VEHICLE_BRAKE"]
		elif stage == 2 and absf(test_car.speed) < 0.01:
			stage = 3
			events = ["VEHICLE_EXIT"]
		elif stage == 3 and not driver.is_seated() and not passenger.is_seated():
			assert(driver.collision_mask == 7 and passenger.collision_mask == 7)
			assert(test_car.health == 600 and driver.health == 100 and passenger.health == 100)
			stage = 4
			events = ["VEHICLE_DONE"]
			print("VEHICLE_LOGIN_SERVER_PASS admitted=2 seats=ok acceleration=ok fuel=ok brake=ok exits=ok")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = DrivingServer.new()
	game.name = "Game"
	root.add_child(game)
