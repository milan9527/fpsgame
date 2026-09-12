extends SceneTree

class ObservedServer:
	extends "res://scripts/game.gd"
	var maximum_actors := 0
	var maximum_vehicles := 0
	var bot_driving_frames := 0
	var last_report := -1
	var reported := false
	var sampled_second := -1
	var transport_samples := {}

	func count_transport(key: String) -> void:
		transport_samples[key] = int(transport_samples.get(key, 0)) + 1

	# Once-per-second observations; never invoke the stateful decision methods.
	func observe_transport() -> void:
		for actor in actors.values():
			if not actor.is_bot or not actor.alive:
				continue
			count_transport("alive_bot_samples")
			if actor.is_seated():
				count_transport("seated")
				continue
			if actor.navigator.driver.approach_point.is_finite():
				count_transport("approaching")
			var nearby := []
			for car in vehicle_fleet.vehicles.values():
				var door: Vector3 = car.to_global(car.seats.DOORS[0]) - Vector3.UP * 0.9
				if actor.position.distance_to(door) <= 12:
					nearby.append(car)
			if nearby.is_empty():
				count_transport("no_nearby_car")
				continue
			if actor.shooting or actor.bot_memory_left > 0:
				count_transport("nearby_but_combat")
				continue
			if actor.health < 50 or actor.heal_left > 0 or actor.downed:
				count_transport("nearby_but_unfit")
				continue
			if zone_state.is_empty():
				count_transport("no_preview")
				continue
			var offset := Vector2(actor.position.x, actor.position.z) - Vector2(zone_state.next_center)
			if offset.length() - float(zone_state.next_radius) <= 25:
				count_transport("nearby_but_short_transfer")
				continue
			var safe: Vector2 = zone_state.next_center + offset.normalized() * maxf(0, zone_state.next_radius - 7)
			var goal := Vector3(safe.x, 0, safe.y)
			var usable := false
			var clear_route := false
			for car in nearby:
				if car.destroyed or not car.grounded or car.fuel < 5 or car.seats.occupant(0) != null or absf(car.speed) > 0.1:
					continue
				usable = true
				var delta: Vector3 = goal - car.position
				if absf(wrapf(atan2(-delta.x, -delta.z) - car.rotation.y, -PI, PI)) <= 0.5:
					clear_route = clear_route or actor.navigator.driver.flat_route(car, goal, actor)
				else:
					clear_route = clear_route or not actor.navigator.driver.turning_route(car, goal, actor).is_empty()
			count_transport("route_available" if clear_route else ("route_rejected" if usable else "car_unavailable"))

	func _physics_process(dt: float) -> void:
		assert(Engine.time_scale == 1.0 and dt <= 0.05)
		super._physics_process(dt)
		if phase == "live":
			if int(elapsed) != sampled_second:
				sampled_second = int(elapsed)
				observe_transport()
			maximum_actors = maxi(maximum_actors, actors.size())
			maximum_vehicles = maxi(maximum_vehicles, vehicle_fleet.vehicles.size())
			for car in vehicle_fleet.vehicles.values():
				if car.driver_id < 0 and absf(car.speed) > 1:
					bot_driving_frames += 1
			if int(elapsed) / 30 != last_report:
				last_report = int(elapsed) / 30
				print("NATURAL_ROUND_PROGRESS elapsed=%.1f alive=%d vehicles=%d bot_driving_frames=%d" % [elapsed, alive_count(), vehicle_fleet.vehicles.size(), bot_driving_frames])
		elif phase == "finished" and not reported:
			reported = true
			assert(maximum_actors == 16 and maximum_vehicles == 4)
			print("NATURAL_ROUND_FINISHED " + JSON.stringify({
				"match_id": match_id, "mode": match_mode, "elapsed": elapsed,
				"actors": maximum_actors, "vehicles": maximum_vehicles,
				"bot_driving_frames": bot_driving_frames, "time_scale": Engine.time_scale,
				"transport_samples": transport_samples
			}))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = ObservedServer.new()
	game.name = "Game"
	root.add_child(game)
