extends RefCounted

const RATE := 22050
const MAX_CARS := 8
const REACH := 100.0
var streams := {}
var emitters := {}
var nearest_cars := []
var nearest_distances := PackedFloat64Array()
var selected := {}
var stale_emitters: Array[int] = []
var occlusion_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)

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
	# Muted/menu updates can call clear every frame with no active emitters.
	if emitters.is_empty():
		return
	for id in emitters.keys():
		remove(id)

func set_volume(volume: float) -> void:
	for entry in emitters.values():
		for player in entry.players.values():
			player.volume_db = linear_to_db(maxf(0.00001, volume * player.get_meta("gain", 0.0)))
		entry.volume = volume

func update(sound, fleet, dt: float, live: bool) -> void:
	if not live or sound.volume <= 0:
		clear()
		return
	if not is_finite(dt) or dt <= 0:
		return
	nearest_cars.clear()
	nearest_distances.clear()
	selected.clear()
	var listener_position := Vector3.ZERO
	var listener_position_ready := false
	# Iterate the fleet directly instead of allocating a values snapshot each
	# rendered frame. Selection does not mutate the fleet.
	for vehicle_id in fleet.vehicles:
		var car = fleet.vehicles[vehicle_id]
		# Parked, silent vehicles need no world-transform or distance query.
		# Keep rolling vehicles audible even without a driver or working engine.
		if not ((car.driver_id != 0 and car.fuel > 0 and not car.destroyed) or absf(car.speed) > 0.25):
			continue
		# Most on-foot frames have only silent parked vehicles. Resolve the
		# listener transform only when an audible candidate needs a distance.
		if not listener_position_ready:
			listener_position = sound.listener.global_position
			listener_position_ready = true
		var distance: float = listener_position.distance_squared_to(car.global_position)
		if distance < REACH * REACH:
			# Keep only the nearest audible cars; no per-car dictionaries,
			# full-fleet sort callback, or sliced temporary array.
			var count := nearest_cars.size()
			if count == MAX_CARS and distance >= nearest_distances[count - 1]:
				continue
			# Upper bound preserves fleet order for equal distances while
			# bounding comparisons when many closer cars arrive last.
			var index := 0
			var end := count
			while index < end:
				var middle := (index + end) >> 1
				if distance < nearest_distances[middle]:
					end = middle
				else:
					index = middle + 1
			if index < MAX_CARS:
				nearest_cars.insert(index, car)
				nearest_distances.insert(index, distance)
				if nearest_cars.size() > MAX_CARS:
					nearest_cars.resize(MAX_CARS)
					nearest_distances.resize(MAX_CARS)
	for car in nearest_cars:
		selected[car.vehicle_id] = car
	nearest_cars.clear()
	# Defer removals until iteration ends, reusing the removal list instead of
	# copying all emitter keys even when no car leaves the audible selection.
	stale_emitters.clear()
	for id in emitters:
		if not selected.has(id):
			stale_emitters.append(id)
	for id in stale_emitters:
		remove(id)
	stale_emitters.clear()
	# All due occlusion rays use the listener's same physics space. Resolve it
	# lazily once for this update; do not retain it across world/round changes.
	var occlusion_space: PhysicsDirectSpaceState3D
	for id in selected:
		var car = selected[id]
		var filter_changed := false
		if not emitters.has(id):
			filter_changed = true
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
			emitters[id] = {"players": players, "speed": absf(car.speed), "occlusion_due": 0.0, "occluded": false, "volume": -1.0}
		var entry: Dictionary = emitters[id]
		var volume_changed: bool = entry.volume != sound.volume
		var previous: float = entry.speed
		entry.speed = lerpf(previous, absf(car.speed), minf(dt * 8, 1))
		var acceleration: float = (entry.speed - previous) / dt
		entry.occlusion_due -= dt
		var origin: Vector3 = car.global_position + Vector3.UP * 0.8
		if entry.occlusion_due <= 0:
			entry.occlusion_due = 0.2
			if occlusion_space == null:
				occlusion_space = sound.listener.get_world_3d().direct_space_state
			occlusion_query.from = listener_position
			occlusion_query.to = origin
			var occluded: bool = not occlusion_space.intersect_ray(occlusion_query).is_empty()
			filter_changed = filter_changed or occluded != entry.occluded
			entry.occluded = occluded
		var engine_on: bool = car.driver_id != 0 and car.fuel > 0 and not car.destroyed
		var speed_ratio := clampf(float(entry.speed) / 22, 0, 1)
		for kind in entry.players:
			var player: AudioStreamPlayer3D = entry.players[kind]
			# Avoid a temporary gain dictionary for every audible car every frame.
			var gain: float = 0.0
			match kind:
				"engine":
					gain = (0.22 + speed_ratio * 0.25) if engine_on else 0.0
				"road":
					gain = speed_ratio * 0.26 if car.grounded else 0.0
				"brake":
					gain = clampf((-acceleration - 3) / 12, 0, 1) * 0.17 if car.grounded and entry.speed > 3 else 0.0
			gain *= 0.35 if entry.occluded else 1.0
			var gain_changed: bool = player.get_meta("gain") != gain
			if gain_changed:
				player.set_meta("gain", gain)
			# Idle and silent layers keep the same gain across frames. Convert
			# to decibels only when an input changes, including volume controls.
			if gain_changed or volume_changed:
				var volume_db := linear_to_db(maxf(0.00001, sound.volume * gain))
				# Audio properties may round to float32; tolerate that rounding.
				if not is_equal_approx(player.volume_db, volume_db):
					player.volume_db = volume_db
			# The filter only changes with occlusion (or a newly created player).
			if filter_changed:
				player.attenuation_filter_cutoff_hz = 1600 if entry.occluded else 12000
			# Silent road/brake layers need no spatial or pitch updates. Sync
			# both below before playback resumes, including moving proxies.
			if gain <= 0.001:
				if player.playing:
					player.stop()
				continue
			# Exact equality preserves even slow audible motion.
			if player.global_position != origin:
				player.global_position = origin
			var pitch := (0.75 + speed_ratio * 1.8) if kind == "engine" else (0.8 + speed_ratio * 0.7)
			if not is_equal_approx(player.pitch_scale, pitch):
				player.pitch_scale = pitch
			if not player.playing:
				player.play()
		entry.volume = sound.volume
	selected.clear()
