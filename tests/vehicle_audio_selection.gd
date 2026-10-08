extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var listener := AudioListener3D.new()
	host.add_child(listener)
	var sound = load("res://scripts/sound.gd").new()
	host.add_child(sound)
	sound.listener = listener
	sound.volume = 1
	var audio = sound.vehicle_audio
	var fleet := {"vehicles": {}}
	for i in range(16):
		var car = load("res://scripts/vehicle.gd").new()
		host.add_child(car)
		car.set_physics_process(false)
		car.vehicle_id = i + 1
		car.driver_id = 1
		car.grounded = true
		car.position = Vector3(16 - i, 0, -4)
		fleet.vehicles[car.vehicle_id] = car
	await physics_frame
	for step in range(32):
		listener.position.x = float(step) - 8
		fleet.vehicles[1].fuel = 0 if step % 2 == 0 else 100
		fleet.vehicles[2].destroyed = step % 3 == 0
		fleet.vehicles[3].driver_id = 0 if step % 2 == 0 else 1
		var reference := []
		for car in fleet.vehicles.values():
			var distance: float = listener.global_position.distance_squared_to(car.global_position)
			if distance < audio.REACH * audio.REACH and ((car.driver_id != 0 and car.fuel > 0 and not car.destroyed) or absf(car.speed) > 0.25):
				reference.append({"car": car, "distance": distance})
		reference.sort_custom(func(a, b): return a.distance < b.distance)
		audio.update(sound, fleet, 0.25, true)
		assert(audio.emitters.size() == mini(reference.size(), audio.MAX_CARS))
		for item in reference.slice(0, audio.MAX_CARS):
			assert(audio.emitters.has(item.car.vehicle_id))
			var entry: Dictionary = audio.emitters[item.car.vehicle_id]
			assert(entry.players.engine.playing)
			assert(is_equal_approx(float(entry.players.engine.get_meta("gain")), 0.22))
			assert(not entry.players.road.playing)
		assert(audio.selected.is_empty() and audio.nearest_cars.is_empty())
	# Equal distances at the eighth-car boundary retain fleet order, including
	# when emitters from the previous moving-listener selection already exist.
	listener.position = Vector3.ZERO
	for car in fleet.vehicles.values():
		car.position = Vector3(4, 0, -4)
		car.driver_id = 1
		car.fuel = 100
		car.destroyed = false
	audio.update(sound, fleet, 0.25, true)
	assert(audio.emitters.size() == audio.MAX_CARS)
	for id in range(1, audio.MAX_CARS + 1):
		assert(audio.emitters.has(id))
	# Silent parked cars must release their emitters, while a driverless,
	# empty-fuel wreck rolling backwards must still produce road audio.
	for car in fleet.vehicles.values():
		car.driver_id = 0
		car.speed = 0
	listener.position = Vector3.ZERO
	audio.update(sound, fleet, 0.25, true)
	assert(audio.emitters.is_empty())
	var rolling = fleet.vehicles[1]
	rolling.fuel = 0
	rolling.destroyed = true
	rolling.speed = -8
	audio.update(sound, fleet, 0.25, true)
	assert(audio.emitters.size() == 1 and audio.emitters.has(rolling.vehicle_id))
	assert(audio.emitters[rolling.vehicle_id].players.road.playing)
	assert(not audio.emitters[rolling.vehicle_id].players.engine.playing)
	listener.position.x = 200
	audio.update(sound, fleet, 0.25, true)
	assert(audio.emitters.is_empty())
	audio.clear()
	host.queue_free()
	await process_frame
	print("VEHICLE_AUDIO_SELECTION_PASS moving_listener=32 fuel=ok wreck=ok nearest_eight=ok ties=ok gain=ok parked=ok driverless_rolling=ok out_of_range=ok")
	quit()
