extends RefCounted

const RATE := 22050
const MAX_CARS := 8
const REACH := 100.0
var streams := {}
var emitters := {}

func prepare() -> void:
	for kind in ["engine", "road", "brake"]:
		if not streams.has(kind):
			streams[kind] = make_stream(kind)

func make_stream(kind: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(RATE * 2)
	# Integer harmonics complete whole cycles in one second, making the loop
	# periodic without a crossfade gap or random discontinuity at its boundary.
	for i in range(RATE):
		var t := float(i) / RATE
		var sample := 0.0
		if kind == "engine":
			sample = (sin(TAU * 60 * t) * 0.48 + sin(TAU * 120 * t) * 0.24 + sin(TAU * 180 * t) * 0.13 + sin(TAU * 300 * t) * 0.07) * (0.82 + 0.18 * cos(TAU * 20 * t))
		elif kind == "road":
			for j in range(12):
				sample += sin(TAU * (193 + j * 137) * t + j * 0.71) * 0.04
			sample *= 0.65 + 0.35 * cos(TAU * 23 * t)
		else:
			sample = sin(TAU * 930 * t + 2.0 * sin(TAU * 37 * t)) * 0.30 + sin(TAU * 1470 * t) * 0.12
		data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 24000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = RATE
	return stream

func remove(id: int) -> void:
	for player in emitters[id].players.values():
		player.stop()
		player.queue_free()
	emitters.erase(id)

func clear() -> void:
	for id in emitters.keys():
		remove(id)

func set_volume(volume: float) -> void:
	for entry in emitters.values():
		for player in entry.players.values():
			player.volume_db = linear_to_db(maxf(0.00001, volume * player.get_meta("gain", 0.0)))

func update(sound, fleet, dt: float, live: bool) -> void:
	if not live or sound.volume <= 0:
		clear()
		return
	if not is_finite(dt) or dt <= 0:
		return
	var candidates := []
	for car in fleet.vehicles.values():
		var distance: float = sound.listener.global_position.distance_squared_to(car.global_position)
		if distance < REACH * REACH and ((car.driver_id != 0 and car.fuel > 0 and not car.destroyed) or absf(car.speed) > 0.25):
			candidates.append({"car": car, "distance": distance})
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	var selected := {}
	for candidate in candidates.slice(0, MAX_CARS):
		selected[candidate.car.vehicle_id] = candidate.car
	for id in emitters.keys():
		if not selected.has(id):
			remove(id)
	for id in selected:
		var car = selected[id]
		if not emitters.has(id):
			var players := {}
			for kind in ["engine", "road", "brake"]:
				var player := AudioStreamPlayer3D.new()
				player.stream = streams[kind]
				player.bus = sound.bus_name
				player.max_distance = REACH
				player.unit_size = 6
				player.volume_db = -80
				player.set_meta("gain", 0.0)
				sound.add_child(player)
				players[kind] = player
			emitters[id] = {"players": players, "speed": absf(car.speed), "occlusion_due": 0.0, "occluded": false}
		var entry: Dictionary = emitters[id]
		var previous: float = entry.speed
		entry.speed = lerpf(previous, absf(car.speed), minf(dt * 8, 1))
		var acceleration: float = (entry.speed - previous) / dt
		entry.occlusion_due -= dt
		var origin: Vector3 = car.global_position + Vector3.UP * 0.8
		if entry.occlusion_due <= 0:
			entry.occlusion_due = 0.2
			var ray := PhysicsRayQueryParameters3D.create(sound.listener.global_position, origin, 1)
			entry.occluded = not sound.listener.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var engine_on: bool = car.driver_id != 0 and car.fuel > 0 and not car.destroyed
		var speed_ratio := clampf(float(entry.speed) / 22, 0, 1)
		var gains := {"engine": (0.22 + speed_ratio * 0.25) if engine_on else 0.0,
			"road": speed_ratio * 0.26 if car.grounded else 0.0,
			"brake": clampf((-acceleration - 3) / 12, 0, 1) * 0.17 if car.grounded and entry.speed > 3 else 0.0}
		for kind in entry.players:
			var player: AudioStreamPlayer3D = entry.players[kind]
			player.global_position = origin
			var gain: float = gains[kind] * (0.35 if entry.occluded else 1.0)
			player.set_meta("gain", gain)
			player.volume_db = linear_to_db(maxf(0.00001, sound.volume * gain))
			player.attenuation_filter_cutoff_hz = 1600 if entry.occluded else 12000
			player.pitch_scale = (0.75 + speed_ratio * 1.8) if kind == "engine" else (0.8 + speed_ratio * 0.7)
			if gain > 0.001 and not player.playing:
				player.play()
			elif gain <= 0.001 and player.playing:
				player.stop()
