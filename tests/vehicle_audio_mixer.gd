extends SceneTree
var sound
var fleet
var recorder: AudioEffectRecord

func _initialize() -> void:
	call_deferred("run")

func energy(label: String) -> Vector2:
	await create_timer(0.15).timeout
	recorder.set_recording_active(true)
	await create_timer(0.35).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	assert(recording != null and recording.stereo and recording.data.size() > 1000)
	var levels := Vector2.ZERO
	for offset in range(0, recording.data.size() - 3, 4):
		levels.x += float(recording.data.decode_s16(offset)) ** 2
		levels.y += float(recording.data.decode_s16(offset + 2)) ** 2
	var path := OS.get_environment("AUDIO_ARTIFACT_DIR")
	if not path.is_empty():
		assert(DirAccess.make_dir_recursive_absolute(path) == OK)
		assert(recording.save_to_wav(path.path_join("vehicle-" + label + ".wav")) == OK)
	return levels / (recording.data.size() / 4.0)

func run() -> void:
	# Isolated real audio mixer fixture; full-world integration remains in vehicle_audio.gd.
	var game := Node3D.new()
	root.add_child(game)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(0, 1.6, 0)
	camera.make_current()
	sound = load("res://scripts/sound.gd").new()
	game.add_child(sound)
	fleet = load("res://scripts/vehicle_fleet.gd").new()
	sound.volume = 1
	sound.listener.global_position = Vector3(0, 1.6, 0)
	await process_frame
	recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(sound.bus_name), recorder)
	var car = fleet.spawn(game, Vector3(-6, 0, -4))
	car.driver_id = 1
	car.grounded = true
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	var entry: Dictionary = sound.vehicle_audio.emitters[car.vehicle_id]
	assert(entry.players.engine.playing and not entry.players.road.playing)
	assert(entry.players.engine.attenuation_filter_cutoff_hz == 12000)
	var idle_pitch: float = entry.players.engine.pitch_scale
	var left := await energy("left")
	assert(left.x > left.y * 1.1 and left.x + left.y > 1000, "Engine must be audible and spatially panned")
	sound.volume = 0.5
	for i in range(8):
		sound.vehicle_audio.update(sound, fleet, 0.01, true)
	var half_volume := await energy("half-volume")
	var energy_ratio := (half_volume.x + half_volume.y) / (left.x + left.y)
	assert(energy_ratio > 0.20 and energy_ratio < 0.30, "Unchanged idle gain must retain the new master volume")
	sound.volume = 1
	sound.vehicle_audio.update(sound, fleet, 0.01, true)
	assert(is_equal_approx(entry.players.engine.volume_db, linear_to_db(0.22)))
	paused = true
	var paused_energy := await energy("paused")
	assert(paused_energy.x + paused_energy.y < 1)
	paused = false
	car.position.x = 6
	sound.vehicle_audio.update(sound, fleet, 0.25, true)
	var right := await energy("right")
	assert(right.y > right.x * 1.1)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 2)
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = Vector3(3, 1, -2)
	await physics_frame
	await physics_frame
	sound.vehicle_audio.update(sound, fleet, 0.25, true)
	assert(entry.occluded and entry.players.engine.attenuation_filter_cutoff_hz == 1600)
	var occluded := await energy("occluded")
	assert(occluded.x + occluded.y < (right.x + right.y) * 0.3)
	wall.queue_free()
	await physics_frame
	await physics_frame
	car.position = Vector3(50, 0, -4)
	sound.vehicle_audio.update(sound, fleet, 0.25, true)
	assert(not entry.occluded and entry.players.engine.attenuation_filter_cutoff_hz == 12000)
	var far := await energy("far")
	assert(far.x + far.y < (right.x + right.y) * 0.3, "Distant engines must attenuate")
	car.position = Vector3(6, 0, -4)
	car.speed = 20
	sound.vehicle_audio.update(sound, fleet, 0.25, true)
	assert(entry.players.engine.pitch_scale > idle_pitch * 2 and entry.players.road.playing)
	car.speed = 5
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(entry.players.brake.playing and entry.players.brake.get_meta("gain") > 0)
	# Snapshot-only proxies use the same output, without local pedal state.
	car.authoritative = false
	car.fuel = 0
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(not entry.players.engine.playing and entry.players.road.playing)
	car.fuel = 100
	car.destroyed = true
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(not entry.players.engine.playing)
	car.destroyed = false
	car.speed = 0
	sound.vehicle_audio.update(sound, fleet, 0.25, true)
	assert(entry.players.engine.playing)
	sound.volume = 0
	var muted := await energy("muted")
	assert(muted.x + muted.y < 1, "Volume control must silence ongoing loops immediately")
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(sound.vehicle_audio.emitters.is_empty())
	sound.volume = 1
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(sound.vehicle_audio.emitters.size() == 1)
	sound.vehicle_audio.update(sound, fleet, 0.05, false)
	assert(sound.vehicle_audio.emitters.is_empty())
	for i in range(12):
		var other = fleet.spawn(game, Vector3(i + 2, 0, -4))
		other.driver_id = 1
	sound.vehicle_audio.update(sound, fleet, 0.05, true)
	assert(sound.vehicle_audio.emitters.size() == sound.vehicle_audio.MAX_CARS)
	var players := []
	for item in sound.vehicle_audio.emitters.values():
		players.append_array(item.players.values())
	sound.reset_round()
	assert(sound.vehicle_audio.emitters.is_empty())
	for player in players:
		assert(not player.playing)
	fleet.clear()
	game.queue_free()
	await process_frame
	print("VEHICLE_AUDIO_MIXER_PASS stereo=ok distance=ok occlusion_pcm=ok pause_pcm=ok pitch=ok braking=ok proxy=ok fuel=ok wreck=ok mute_pcm=ok phase=ok bounded=ok cleanup=ok")
	quit()
