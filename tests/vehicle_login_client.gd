extends SceneTree
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	var audio_test := OS.get_environment("VEHICLE_AUDIO_TEST") == "1"
	game.sound.volume = 0.65 if audio_test else 0.0
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
	var saw_network_stop := false
	var saw_network_recovery := false
	var applied_frames := 0
	var last_frame := -1
	var first_frame_at := 0
	var last_frame_at := 0
	var largest_gap := 0
	var saw_vehicle_audio := false
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
		if not game.vehicle_fleet.vehicles.is_empty() and game.vehicle_replica.last_sequence != last_frame:
			var now := Time.get_ticks_msec()
			if first_frame_at == 0:
				first_frame_at = now
			else:
				largest_gap = maxi(largest_gap, now - last_frame_at)
			last_frame_at = now
			last_frame = game.vehicle_replica.last_sequence
			applied_frames += 1
		if stage == "VEHICLE_ENTER" and not actor.is_seated() or stage == "VEHICLE_EXIT" and actor.is_seated():
			if Time.get_ticks_msec() >= next_interact:
				Input.action_press("loot")
				release_interact = true
				next_interact = Time.get_ticks_msec() + 500
		if actor.is_seated():
			saw_seated = true
			var car = actor.vehicle_ref.get_ref()
			assert(not car.authoritative)
			if audio_test and game.sound.vehicle_audio.emitters.has(car.vehicle_id):
				var engine = game.sound.vehicle_audio.emitters[car.vehicle_id].players.engine
				if engine.playing and engine.get_meta("gain") > 0:
					assert(engine.global_position.distance_to(car.global_position + Vector3.UP * 0.8) < 0.5)
					saw_vehicle_audio = true
			if stage == "VEHICLE_NETWORK_PAUSE" and absf(car.speed) < 0.01:
				saw_network_stop = true
			if saw_network_stop and car.speed > 4:
				saw_network_recovery = true
			if car.position.z < -6 and car.fuel < 100:
				saw_motion = true
			if stage == "VEHICLE_BRAKE" or stage == "VEHICLE_EXIT":
				saw_brake = true
			if stage == "VEHICLE_DEPARTURE" and actor.vehicle_seat == 1 and car.driver_id == 0:
				assert(car.seats.occupant(0) == null)
				saw_brake = true
			if actor.vehicle_seat == 0:
				was_driver = true
				if stage in ["VEHICLE_DRIVE", "VEHICLE_DEPARTURE", "VEHICLE_NETWORK_PAUSE"]:
					Input.action_press("forward")
				else:
					Input.action_release("forward")
				if stage in ["VEHICLE_BRAKE", "VEHICLE_EXIT"]:
					Input.action_press("jump")
				else:
					Input.action_release("jump")
		if stage == "VEHICLE_DONE":
			assert(saw_seated and saw_motion and saw_brake and not actor.is_seated())
			if audio_test:
				assert(saw_vehicle_audio)
				print("VEHICLE_NETWORK_AUDIO_PASS proxy_engine=playing position=tracked")
			if OS.get_environment("VEHICLE_IMPAIRED") == "1":
				assert(saw_network_stop and saw_network_recovery)
				var frequency := (applied_frames - 1) * 1000.0 / maxi(1, last_frame_at - first_frame_at)
				assert(frequency >= 8, "Complete paired snapshots must remain frequent under moderate packet disorder")
				print("VEHICLE_NETWORK_FRAME_RATE hz=%.2f max_gap_ms=%d frames=%d" % [frequency, largest_gap, applied_frames])
				print("VEHICLE_NETWORK_CLIENT_RECOVERED seat=stable stopped=observed resumed=observed")
			assert(actor.collision_mask == 7)
			print("VEHICLE_LOGIN_CLIENT_PASS login=ok ticket=ok production_input=ok seat=ok motion=ok fuel=ok brake=ok exit=ok")
			Input.action_release("forward")
			Input.action_release("jump")
			game.request_quit()
			return
