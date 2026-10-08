extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var listener := AudioListener3D.new()
	host.add_child(listener)
	listener.position = Vector3(0, 1, 0)
	var car = load("res://scripts/vehicle.gd").new()
	host.add_child(car)
	car.set_physics_process(false)
	car.vehicle_id = 1
	car.driver_id = 1
	car.position = Vector3(0, 0, -10)
	var audio = load("res://scripts/vehicle_audio.gd").new()
	audio.prepare()
	var sound = load("res://scripts/sound.gd").new()
	host.add_child(sound)
	sound.listener = listener
	sound.volume = 1
	var fleet := {"vehicles": {1: car}}
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 1)
	shape.shape = box
	wall.add_child(shape)
	host.add_child(wall)
	wall.position = Vector3(0, 1, -5)
	await physics_frame
	await physics_frame
	var query_id: int = audio.occlusion_query.get_instance_id()
	for i in range(100):
		car.position.x = 0 if i % 2 == 0 else 20
		audio.update(sound, fleet, 0.25, true)
		var reference := PhysicsRayQueryParameters3D.create(listener.global_position, car.global_position + Vector3.UP * 0.8, 1)
		var blocked := not listener.get_world_3d().direct_space_state.intersect_ray(reference).is_empty()
		assert(blocked == (i % 2 == 0))
		assert(audio.emitters[1].occluded == blocked)
		assert(audio.occlusion_query.get_instance_id() == query_id)
		for player in audio.emitters[1].players.values():
			assert(player.attenuation_filter_cutoff_hz == (1600 if blocked else 12000))
		# Updates between ray polls retain the last filter state.
		audio.update(sound, fleet, 0.01, true)
		for player in audio.emitters[1].players.values():
			assert(player.attenuation_filter_cutoff_hz == (1600 if blocked else 12000))
	# A silent layer may have stale spatial/pitch properties. Reactivation
	# must catch up on the same update, before the stream starts.
	var road: AudioStreamPlayer3D = audio.emitters[1].players.road
	assert(not road.playing)
	car.position = Vector3(7, 0, -10)
	car.grounded = true
	car.speed = 20
	audio.update(sound, fleet, 0.25, true)
	assert(road.playing)
	assert(road.global_position == car.global_position + Vector3.UP * 0.8)
	assert(is_equal_approx(road.pitch_scale, 0.8 + 20.0 / 22.0 * 0.7))
	car.grounded = false
	audio.update(sound, fleet, 0.25, true)
	assert(not road.playing)
	car.position = Vector3(-7, 0, -10)
	car.speed = 10
	car.grounded = true
	audio.update(sound, fleet, 0.25, true)
	assert(road.playing)
	assert(road.global_position == car.global_position + Vector3.UP * 0.8)
	assert(is_equal_approx(road.pitch_scale, 0.8 + 10.0 / 22.0 * 0.7))
	audio.clear()
	host.queue_free()
	await process_frame
	print("VEHICLE_AUDIO_QUERY_REUSE_PASS")
	quit()
