extends SceneTree
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	var deadline := Time.get_ticks_msec() + 65000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	game.bot_client = false
	var next_interact := 0
	var release_interact := false
	var saw_seated := false
	var saw_motion := false
	var saw_brake := false
	var was_driver := false
	while true:
		await physics_frame
		assert(Time.get_ticks_msec() < deadline, "Authenticated client driving timeout")
		if OS.get_environment("VEHICLE_DEPARTURE") == "revoke" and was_driver and not game.running:
			assert(game.token.is_empty() and game.actors.is_empty() and game.vehicle_fleet.vehicles.is_empty())
			print("VEHICLE_REVOKED_CLIENT_PASS signed_out=ok world_cleared=ok")
			game.request_quit()
			return
		if release_interact:
			Input.action_release("loot")
			release_interact = false
		if game.phase != "live" or game.events.is_empty() or not game.actors.has(game.local_id):
			continue
		var actor = game.actors[game.local_id]
		var stage: String = game.events[0]
		if stage == "VEHICLE_ENTER" and not actor.is_seated() or stage == "VEHICLE_EXIT" and actor.is_seated():
			if Time.get_ticks_msec() >= next_interact:
				Input.action_press("loot")
				release_interact = true
				next_interact = Time.get_ticks_msec() + 500
		if actor.is_seated():
			saw_seated = true
			var car = actor.vehicle_ref.get_ref()
			assert(not car.authoritative)
			if car.position.z < -6 and car.fuel < 100:
				saw_motion = true
			if stage == "VEHICLE_BRAKE" or stage == "VEHICLE_EXIT":
				saw_brake = true
			if stage == "VEHICLE_DEPARTURE" and actor.vehicle_seat == 1 and car.driver_id == 0:
				assert(car.seats.occupant(0) == null)
				saw_brake = true
			if actor.vehicle_seat == 0:
				was_driver = true
				if stage in ["VEHICLE_DRIVE", "VEHICLE_DEPARTURE"]:
					Input.action_press("forward")
				else:
					Input.action_release("forward")
				if stage in ["VEHICLE_BRAKE", "VEHICLE_EXIT"]:
					Input.action_press("jump")
				else:
					Input.action_release("jump")
		if stage == "VEHICLE_DONE":
			assert(saw_seated and saw_motion and saw_brake and not actor.is_seated())
			assert(actor.collision_mask == 7)
			print("VEHICLE_LOGIN_CLIENT_PASS login=ok ticket=ok production_input=ok seat=ok motion=ok fuel=ok brake=ok exit=ok")
			Input.action_release("forward")
			Input.action_release("jump")
			game.request_quit()
			return
