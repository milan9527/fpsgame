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
	var impaired := OS.get_environment("VEHICLE_IMPAIRED") == "1"
	var network_recovered := false
	var diagnostic_second := -1
	var combat := OS.get_environment("VEHICLE_COMBAT") == "1"
	var shooter
	var spectating := OS.get_environment("VEHICLE_SPECTATOR") == "1"
	var turn_pose_reported := false
	var boarding_wait := OS.get_environment("VEHICLE_BOARDING_WAIT") == "1"
	var boarding_frames := 0
	var boarding_position := Vector3.INF
	var bot_turn := OS.get_environment("VEHICLE_BOT_TURN")
	var turn_goal := Vector3.ZERO
	var bot_driving := OS.get_environment("VEHICLE_BOT_DRIVER") == "1"
	func shot_rewind_age(actor) -> float:
		var age: float = super.shot_rewind_age(actor)
		if combat and actor == shooter and driver.is_seated():
			var direction := Basis(Vector3.UP, actor.yaw) * Basis(Vector3.RIGHT, actor.pitch + actor.recoil) * Vector3.FORWARD
			var origin: Vector3 = actor.eye_position()
			var best_error := INF
			var best_age := 0.0
			for step in range(41):
				var sample_age := step * 0.005
				var poses: Dictionary = hit_history.poses_at(elapsed - sample_age)
				if not poses.has(driver_peer) or not poses[driver_peer].has("boxes"):
					continue
				var pose: Dictionary = poses[driver_peer]
				for box in pose.boxes:
					if box.bone != "Hips":
						continue
					var point: Vector3 = pose.p + pose.basis * (box.transform * box.bounds.get_center())
					var delta := point - origin
					var error := (delta - direction * delta.dot(direction)).length()
					if error < best_error:
						best_error = error
						best_age = sample_age
			var hit: Dictionary = trace_shot(actor, origin, direction, age)
			var name := "miss" if hit.is_empty() else str(hit.collider.name)
			print("VEHICLE_AIM_DIAGNOSTIC time=%.3f protected=%s ammo=%d configured_ms=%d matched_ms=%d error=%.4f speed=%.2f hit=%s part=%s" % [elapsed, str(elapsed < 5), actor.ammo, int(age * 1000), int(best_age * 1000), best_error, test_car.speed, name, str(hit.get("part", hit.get("bone", "")))])
		return age
	func reset_round() -> void:
		super.reset_round()
		phase_time = 8
	func begin_round() -> void:
		assert(sessions.size() == (1 if bot_driving else (3 if combat or spectating else 2)), "Required backend-authenticated clients must be admitted")
		super.begin_round()
		var ids: Array = sessions.keys()
		ids.sort()
		if (combat or spectating) and match_mode == "duo":
			for id in ids:
				var allies: Array = ids.filter(func(peer): return actors[peer].team_id == actors[id].team_id)
				if allies.size() == 2:
					ids = allies + ids.filter(func(peer): return not allies.has(peer))
					break
		driver = actors[ids[0]]
		driver_peer = ids[0]
		passenger = actors[ids[0] if bot_driving else (ids[2] if spectating else ids[1])]
		if bot_driving:
			for actor in actors.values():
				if actor.is_bot and teams.friendly(passenger.actor_id, actor.actor_id):
					driver = actor
					driver_peer = actor.actor_id
					break
			assert(driver.is_bot and teams.friendly(passenger.actor_id, driver.actor_id))
		if combat:
			shooter = actors[ids[2]]
		for actor in actors.values():
			# Keep inactive bots inside the initial zone. Their deaths must not
			# finish the match while waiting for a disconnected peer's timeout.
			actor.position = Vector3(60, 0.1, 30 + abs(actor.actor_id) % 12)
		driver.position = Vector3(-1.65, 0.04, 0.1)
		if bot_driving:
			driver.position.x = -6
		passenger.position = Vector3(1.65, 0.04, 0.1)
		if combat:
			shooter.position = Vector3(-8, 0.04, -6)
			driver.armor = 0
			assert(not teams.friendly(driver.actor_id, shooter.actor_id))
		test_car = vehicle_fleet.spawn(self, Vector3(0, 0.04, 0))
		vehicle_fleet.map_spawned = true
		events = ["VEHICLE_ENTER"]
		if spectating:
			var observer = actors[ids[1]]
			assert(teams.friendly(driver.actor_id, observer.actor_id))
			damage(observer, 10000, passenger.actor_id, true)
			damage(observer, 10000, passenger.actor_id, true)
			assert(not observer.alive and driver.alive)
			print("VEHICLE_SPECTATOR_SERVER_READY eliminated=ok teammate=ok")
	func bot_input(actor, _dt: float) -> void:
		if bot_driving and actor == driver and (passenger.is_seated() or boarding_wait) and (stage < 2 or driver.is_seated()):
			# Supply a nearby evacuation objective without altering team allocation,
			# navigation, driver controls, seats, or physical vehicle motion.
			var previous_zone := zone
			var previous_center := zone_center
			var previous_state := zone_state
			zone = 5
			turn_goal = Vector3(-35 if bot_turn == "left" else 35, 0, -5)
			zone_center = Vector2(turn_goal.x, turn_goal.z) if not bot_turn.is_empty() else Vector2(0, -35)
			zone_state = {}
			super.bot_input(actor, _dt)
			zone = previous_zone
			zone_center = previous_center
			zone_state = previous_state
			return
		actor.move_input = Vector2.ZERO
		actor.shooting = false
	func revoke_account_peer(id: int) -> void:
		super.revoke_account_peer(id)
		if id == driver_peer:
			assert(test_car.throttle == 0 and test_car.input_age >= test_car.INPUT_TIMEOUT)
			print("VEHICLE_REVOCATION_INPUT_CLEARED")
	func _physics_process(dt: float) -> void:
		var before_pose: Vector3 = test_car.position if is_instance_valid(test_car) else Vector3.ZERO
		var hull_before: float = test_car.health if is_instance_valid(test_car) else -1
		super._physics_process(dt)
		if stage >= 3 and not bot_turn.is_empty() and is_instance_valid(test_car):
			assert(test_car.position.distance_to(before_pose) < 0.03,
				"Stopped chassis must not jump during rider collision restoration")
		if stage == 4:
			done_elapsed += dt
			if not bot_turn.is_empty() and done_elapsed >= 1 and not turn_pose_reported:
				turn_pose_reported = true
				print("VEHICLE_BOT_TURN_POSE ", JSON.stringify({"position": [test_car.position.x, test_car.position.y, test_car.position.z], "yaw": test_car.rotation.y}))
			if done_elapsed > 2:
				request_quit()
			return
		if test_car == null:
			return
		if boarding_wait and stage == 0 and driver.is_seated() and not passenger.is_seated():
			if not boarding_position.is_finite():
				boarding_position = test_car.position
			assert(absf(test_car.speed) < 0.01 and test_car.position.distance_to(boarding_position) < 0.03)
			boarding_frames += 1
		test_elapsed += dt
		if impaired and int(test_elapsed) / 5 != diagnostic_second:
			diagnostic_second = int(test_elapsed) / 5
			print("VEHICLE_NETWORK_PROGRESS stage=%d phase=%s speed=%.2f position=%s" % [stage, phase, test_car.speed, str(test_car.position)])
		assert(test_elapsed < 45, "Authenticated driving did not complete")
		if stage == 0 and driver.is_seated() and passenger.is_seated() and (not combat or elapsed >= 5.5):
			assert(driver.vehicle_seat == 0 and passenger.vehicle_seat == 1)
			if boarding_wait:
				assert(boarding_frames >= 30, "Real AI must wait while passenger has not boarded")
				print("BOT_BOARDING_SERVER_PASS waiting_frames=", boarding_frames, " passenger=boarded")
			stage = 1
			events = ["VEHICLE_DRIVE"]
		elif stage == 1 and combat and test_car.position.z < -3 and test_car.speed >= 12:
			stage = 9
			events = ["VEHICLE_COMBAT"]
		elif stage == 9 and driver.health < 100:
			assert(test_car.speed > 4 and driver.alive and driver.is_seated())
			assert(test_car.health == hull_before and test_car.health > 0 and passenger.alive and shooter.ammo < 30, "A driver hit must not also damage the hull in the same frame")
			assert(elapsed > 5 and shooter.ammo >= 28 and passenger.health == 100, "Unprotected moving driver must be hit promptly without hitting the passenger")
			assert(rewind_peers.has(shooter.actor_id), "Real network shooter must use authoritative rewind")
			print("VEHICLE_COMBAT_SERVER_HIT health=%.2f hull=%.2f passenger=%.2f speed=%.2f ammo=%d rewind=ok" % [driver.health, test_car.health, passenger.health, test_car.speed, shooter.ammo])
			stage = 2
			events = ["VEHICLE_BRAKE"]
		elif stage == 1 and impaired and not network_recovered and test_car.position.z < -3:
			stage = 7
			events = ["VEHICLE_NETWORK_PAUSE"]
			print("VEHICLE_NETWORK_BLACKOUT_READY")
		elif stage == 7:
			# At top speed the 350 ms expiry plus 22/16 s braking distance
			# needs up to 1.725 s; do not demand an instantaneous stop.
			if test_car.input_age > 2.0:
				assert(absf(test_car.speed) < 0.01 and driver.is_seated() and passenger.is_seated())
				assert(test_car.driver_id == driver_peer)
				stage = 8
				print("VEHICLE_NETWORK_TIMEOUT_BRAKED")
		elif stage == 8:
			if test_car.speed > 4:
				network_recovered = true
				stage = 1
				events = ["VEHICLE_DRIVE"]
				print("VEHICLE_NETWORK_RECOVERED")
		elif stage == 1 and bot_driving and not bot_turn.is_empty() and driver.navigator.driver.stopping:
			assert(test_car.position.distance_to(turn_goal) < 7 and absf(test_car.rotation.y) > 0.8)
			stage = 2
			events = ["VEHICLE_BRAKE"]
		elif stage == 1 and not combat and test_car.position.z < -8 and test_car.speed > 8:
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
				print("VEHICLE_DEPARTURE_RELEASED driver=0 seat=empty passenger=secured stopped=ok phase=%s elapsed=%.2f" % [phase, elapsed])
		elif stage == 2 and absf(test_car.speed) < 0.01:
			stage = 3
			events = ["VEHICLE_EXIT"]
		elif stage == 3 and (not departure.is_empty() or not driver.is_seated()) and not passenger.is_seated():
			assert(phase == "live", "Vehicle exit must complete before round cleanup, not because actors were cleared")
			assert(passenger.collision_mask == 7)
			assert(test_car.health > 0 and passenger.health > 0 if combat else test_car.health == 600 and passenger.health == 100)
			if departure.is_empty():
				assert(driver.collision_mask == 7)
				assert(driver.health > 0 and driver.health < 100 if combat else driver.health == 100)
			stage = 4
			events = ["VEHICLE_DONE"]
			if bot_driving:
				assert(driver.is_bot and driver.navigator.driver.cooldown > 0)
				if bot_turn.is_empty():
					assert(test_car.position.z < -28)
				else:
					assert(test_car.position.distance_to(turn_goal) < 6 and absf(test_car.speed) < 0.1)
					print("VEHICLE_BOT_TURN_EXIT_POSE ", JSON.stringify({"position": [test_car.position.x, test_car.position.y, test_car.position.z], "yaw": test_car.rotation.y}))
				print("VEHICLE_BOT_DRIVER_SERVER_PASS assigned_teammate=ok normal_ai=ok destination=ok parked=ok exit=ok")
			print("VEHICLE_LOGIN_SERVER_PASS admitted=%d seats=ok acceleration=ok fuel=ok brake=ok exits=ok" % participants.size())

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = DrivingServer.new()
	game.name = "Game"
	root.add_child(game)
