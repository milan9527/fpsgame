extends Node

const RATE := 22050
const MAX_VOICES := 48
var banks: Dictionary = {}
var voices: Array[Node] = []
var actor_states: Dictionary = {}
var played_events: Dictionary = {}
var listener: AudioListener3D
var bus_name := ""
var vehicle_audio = preload("res://scripts/vehicle_audio.gd").new()
var volume := 0.65:
	set(value):
		volume = clampf(value, 0, 1)
		vehicle_audio.set_volume(volume)
		for voice in voices:
			if is_instance_valid(voice):
				voice.volume_db = linear_to_db(maxf(0.00001, volume * float(voice.get_meta("gain"))))

func _ready() -> void:
	bus_name = "GameSFX_" + str(get_instance_id())
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, bus_name)
	var limiter := AudioEffectLimiter.new()
	limiter.threshold_db = -3
	limiter.ceiling_db = -1
	AudioServer.add_bus_effect(bus, limiter)
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	get_viewport().audio_listener_enable_3d = true
	var durations := {"gun_ar": 0.18, "gun_sg": 0.30, "gun_sr": 0.40, "explosion": 1.0, "step_hard": 0.14, "step_grass": 0.18, "land": 0.25, "jump": 0.16, "reload_start": 0.32, "reload_end": 0.20, "heal_start": 0.24, "heal_end": 0.4, "pickup": 0.18, "hit": 0.065, "kill": 0.23, "hurt": 0.20, "throw": 0.13}
	var index := 0
	for name in durations:
		banks[name] = []
		for variant in range(3 if name.begins_with("step_") else 1):
			banks[name].append(synthesize(name, durations[name], index * 31 + variant))
		index += 1
	vehicle_audio.prepare()

func synthesize(name: String, duration: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 713
	var data := PackedByteArray()
	var low := 0.0
	for i in range(int(duration * RATE)):
		var t := float(i) / RATE
		var noise := rng.randf_range(-1, 1)
		low = low * 0.75 + noise * 0.25
		var sample := 0.0
		match name:
			"explosion": sample = (low * 1.2 + sin(t * 48 * TAU) * 0.4) * exp(-t * 5)
			"gun_ar", "gun_sg", "gun_sr":
				var frequency := 100.0 if name == "gun_ar" else (75.0 if name == "gun_sg" else 52.0)
				var decay := 26.0 if name == "gun_ar" else (18.0 if name == "gun_sg" else 12.0)
				sample = (noise * 0.65 + sin(t * (frequency - t * 100) * TAU) * 0.3) * exp(-t * decay)
			"step_hard", "land": sample = (low * 0.8 + sin(t * 82 * TAU) * 0.45) * exp(-t * 24)
			"step_grass", "jump", "throw": sample = (noise * 0.4 + low * 0.6) * exp(-t * 20)
			"reload_start", "reload_end":
				for click in [0.015, 0.09, 0.17]:
					var age: float = t - click
					if age > 0:
						sample += (noise * 0.45 + sin(age * 850 * TAU) * 0.2) * exp(-age * 100)
			"heal_start": sample = noise * 0.35 * sin(t / duration * PI) ** 2
			"heal_end", "pickup", "kill":
				var tone := 440.0 if name == "heal_end" else (660.0 if name == "pickup" else 880.0)
				sample = (sin(t * tone * TAU) + sin(t * tone * 1.5 * TAU)) * 0.23 * exp(-t * 10)
			"hit": sample = noise * 0.5 * exp(-t * 80)
			"hurt": sample = low * 0.9 * exp(-t * 18)
		sample *= minf(1, t / 0.003) * minf(1, (duration - t) / 0.015)
		var pcm := int(clampf(sample, -1, 1) * 24000)
		data.append(pcm & 255)
		data.append((pcm >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func release_voice(voice: Node) -> void:
	voices.erase(voice)
	if is_instance_valid(voice):
		voice.stop()
		voice.queue_free()

func _exit_tree() -> void:
	vehicle_audio.clear()
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
	voices.clear()
	actor_states.clear()
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.remove_bus(bus)

func effect(name: String, at: Vector3, spatial := true, gain := 1.0, priority := 1) -> Node:
	if volume <= 0 or not banks.has(name):
		return null
	var reach := 110.0 if priority >= 2 else 28.0
	if spatial and listener.global_position.distance_to(at) > reach:
		return null
	if voices.size() >= MAX_VOICES:
		var victim: Node = null
		for voice in voices:
			if int(voice.get_meta("priority")) <= priority and (victim == null or int(voice.get_meta("priority")) < int(victim.get_meta("priority"))):
				victim = voice
		if victim == null:
			return null
		release_voice(victim)
	var player = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
	player.bus = bus_name
	var count: int = played_events.get(name, 0)
	player.stream = banks[name][count % banks[name].size()]
	player.set_meta("gain", gain)
	player.set_meta("priority", priority)
	player.set_meta("effect", name)
	player.volume_db = linear_to_db(maxf(0.00001, volume * gain))
	add_child(player)
	if spatial:
		player.global_position = at
		player.max_distance = reach
		player.unit_size = 9 if priority >= 2 else 2
		var query := PhysicsRayQueryParameters3D.create(listener.global_position, at, 1)
		var hit := listener.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			player.volume_db -= 9
			player.set_meta("gain", gain * db_to_linear(-9))
			player.attenuation_filter_cutoff_hz = 1500
	voices.append(player)
	played_events[name] = count + 1
	player.finished.connect(func(): release_voice(player))
	player.play()
	return player

func shot(at: Vector3, kind: int) -> void:
	if kind >= 0 and kind < 4:
		effect(["gun_ar", "gun_sg", "gun_sr", "explosion"][kind], at, true, 1, 2)

func feedback(kind: int, killed: bool) -> void:
	effect(("kill" if killed else "hit") if kind == 0 else "hurt", Vector3.ZERO, false, 0.55, 3)

func update_actors(actors: Dictionary, world, camera: Camera3D) -> void:
	if camera == null:
		return
	listener.global_transform = camera.global_transform
	for id in actor_states.keys():
		if not actors.has(id):
			actor_states.erase(id)
	for id in actors:
		var actor = actors[id]
		var now := {"position": actor.position, "ground": actor.grounded, "vy": actor.velocity.y, "reload": actor.reload_left, "heal": actor.heal_left, "ammo": actor.ammo, "total": actor.ammo + actor.reserve, "med": actor.medkits, "frags": actor.grenades, "armor": actor.armor, "health": actor.health, "throw": actor.throw_left, "distance": 0.0}
		if actor_states.has(id) and actor.alive:
			var previous: Dictionary = actor_states[id]
			var delta: Vector3 = actor.position - previous.position
			var distance := Vector2(delta.x, delta.z).length()
			var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
			var origin: Vector3 = actor.position + Vector3.UP * 0.4
			if actor.grounded and previous.ground and distance < 2.0 and speed > 0.2:
				now.distance = previous.distance + distance
				var stride := 1.6 if actor.crouched else (2.6 if speed > 6 else 2.2)
				if now.distance >= stride:
					now.distance = fmod(now.distance, stride)
					effect(world.footstep_surface(actor.position), origin, true, 0.22 if actor.crouched else (0.85 if speed > 6 else 0.55))
			if previous.ground and not actor.grounded and actor.velocity.y > 1:
				effect("jump", origin, true, 0.4)
			if not previous.ground and actor.grounded and previous.vy < -2:
				effect("land", origin, true, clampf(absf(previous.vy) / 12, 0.25, 1))
			if previous.reload <= 0 and actor.reload_left > 0:
				effect("reload_start", actor.eye_position(), true, 0.55)
			elif previous.reload > 0 and actor.reload_left <= 0 and actor.ammo > previous.ammo:
				effect("reload_end", actor.eye_position(), true, 0.55)
			if previous.heal <= 0 and actor.heal_left > 0:
				effect("heal_start", actor.eye_position(), true, 0.4)
			elif previous.heal > 0 and actor.heal_left <= 0 and actor.health > previous.health:
				effect("heal_end", actor.eye_position(), true, 0.4)
			if previous.throw <= 0 and actor.throw_left > 0:
				effect("throw", actor.eye_position(), true, 0.4)
			if now.total > previous.total or now.med > previous.med or now.frags > previous.frags or now.armor > previous.armor:
				effect("pickup", actor.eye_position(), true, 0.4)
		actor_states[id] = now

func reset_round() -> void:
	vehicle_audio.clear()
	actor_states.clear()
	for voice in voices.duplicate():
		release_voice(voice)
