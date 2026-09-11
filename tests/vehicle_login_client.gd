extends SceneTree
var game
var frame_sample_start := 0
var frame_sample_count := 0

func measure_frame() -> void:
	frame_sample_count += 1
	var now := Time.get_ticks_msec()
	if now - frame_sample_start >= 3000:
		print("VEHICLE_FRAME_RATE requested=%d measured=%.2f" % [Engine.max_fps, frame_sample_count * 1000.0 / (now - frame_sample_start)])
		frame_sample_start = now
		frame_sample_count = 0

func _initialize() -> void:
	Engine.max_fps = int(OS.get_environment("VEHICLE_CLIENT_FPS"))
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
	if Engine.max_fps > 0:
		frame_sample_start = Time.get_ticks_msec()
		process_frame.connect(measure_frame)
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
	var combat := OS.get_environment("VEHICLE_COMBAT") == "1"
	var fire_until := 0
	var next_fire := 0
	var saw_combat_damage := false
	var shooter_moved_target := false
	var spectating := OS.get_environment("VEHICLE_SPECTATOR") == "1"
	var followed_frames := 0
	var followed_moving := false
	var followed_exit := false
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
		if spectating and not actor.alive:
			var view = game.spectator
			if not view.active or view.target_id == 0:
				continue
			var target = game.actors[view.target_id]
			assert(view.camera.current and target.team_id == actor.team_id)
			assert(view.candidates(game.actors) == [target.actor_id])
			if target.is_seated():
				var car = target.vehicle_ref.get_ref()
				assert(not car.authoritative)
				# Proxy motion and spectator pivot are updated together by Game._process.
				assert(view.position.distance_to(car.position + Vector3.UP * 1.4) < 0.05)
				followed_frames += 1
				followed_moving = followed_moving or car.speed > 8
			elif followed_moving:
				followed_exit = view.position.distance_to(target.position + Vector3.UP * target.eye_height()) < 0.05
			if stage == "VEHICLE_DONE" and followed_exit:
				assert(followed_frames > 20 and followed_moving)
				print("VEHICLE_NETWORK_SPECTATOR_PASS login=ok elimination=ok team_only=ok proxy=ok seated_samples=%d speed_over_8=ok exit=ok" % followed_frames)
				game.request_quit()
				return
			continue
		if combat:
			var humans: Array = game.actors.keys().filter(func(id): return id > 0)
			humans.sort()
			if humans.size() == 3:
				if game.match_mode == "duo":
					for id in humans:
						var allies: Array = humans.filter(func(peer): return game.actors[peer].team_id == game.actors[id].team_id)
						if allies.size() == 2:
							humans = allies + humans.filter(func(peer): return not allies.has(peer))
							break
				var driver = game.actors[humans[0]]
				if driver.health < 100 and driver.alive:
					saw_combat_damage = true
				if game.local_id == humans[2]:
					var now := Time.get_ticks_msec()
					if driver.is_seated():
						var car = driver.vehicle_ref.get_ref()
						shooter_moved_target = shooter_moved_target or car.speed > 4
					var direction: Vector3 = (driver.aim_position() - actor.eye_position()).normalized()
					actor.yaw = atan2(-direction.x, -direction.z)
					actor.pitch = asin(direction.y) - actor.recoil
					Input.action_press("aim")
					if stage == "VEHICLE_COMBAT" and not saw_combat_damage and now >= next_fire:
						fire_until = now + 65
						next_fire = now + 600
					if now < fire_until:
						Input.action_press("fire")
					else:
						Input.action_release("fire")
					if stage == "VEHICLE_DONE":
						assert(saw_combat_damage and shooter_moved_target and actor.ammo < 30)
						print("VEHICLE_COMBAT_SHOOTER_PASS login=ok normal_input=ok ammo=ok moving_target=ok replicated_damage=ok")
						Input.action_release("fire")
						Input.action_release("aim")
						game.request_quit()
						return
					continue
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
				if stage in ["VEHICLE_DRIVE", "VEHICLE_DEPARTURE", "VEHICLE_NETWORK_PAUSE", "VEHICLE_COMBAT"]:
					Input.action_press("forward")
				else:
					Input.action_release("forward")
				if stage in ["VEHICLE_BRAKE", "VEHICLE_EXIT"]:
					Input.action_press("jump")
				else:
					Input.action_release("jump")
		if stage == "VEHICLE_DONE":
			if combat:
				assert(saw_combat_damage)
				print("VEHICLE_COMBAT_OCCUPANT_PASS replicated_damage=ok seat_preserved=ok")
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
