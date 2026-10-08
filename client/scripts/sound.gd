extends Node

const RATE := 22050
const SHOT_EFFECTS := ["gun_ar", "gun_sg", "gun_sr", "explosion"]
const RELOAD_CLICK_TIMES := [0.015, 0.09, 0.17]
const MAX_VOICES := 48
const MAX_IDLE_VOICES_PER_TYPE := 16
const SPATIAL_REACH := 28.0
const PRIORITY_SPATIAL_REACH := 110.0
class ActorAudioState:
	extends RefCounted
	# Fixed layout for the snapshot read and written for every actor/frame.
	var position := Vector3.ZERO
	var ground := false
	var vy := 0.0
	var reload := 0.0
	var heal := 0.0
	var ammo := 0
	var total := 0
	var med := 0
	var frags := 0
	var armor := 0.0
	var health := 0.0
	var throw := 0.0
	var distance := 0.0

var banks: Dictionary = {}
var voices: Array[Node] = []
var idle_spatial: Array[Node] = []
var idle_flat: Array[Node] = []
var actor_states: Dictionary = {}
var retired_actor_ids: Array = []
var played_events: Dictionary = {}
var listener: AudioListener3D
var bus_name := ""
# effect() performs synchronous raycasts on the main thread; each sound manager
# can reuse its parameters while refreshing both endpoints for every event.
var occlusion_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1)
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
	if OS.has_feature("android"):
		warm_voices()

func warm_voices() -> void:
	# Allocate silent players during loading, before the first combat burst.
	# Fill directly: acquire_voice() would repeatedly pop the same idle node.
	for spatial in [true, false]:
		var pool := idle_spatial if spatial else idle_flat
		while pool.size() < MAX_IDLE_VOICES_PER_TYPE:
			pool.append(create_voice(spatial))

func synthesize(name: String, duration: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 713
	var data := PackedByteArray()
	var sample_count := int(duration * RATE)
	# PCM size is known up front; avoid growing the buffer twice per sample
	# while preparing the sound banks during scene loading.
	data.resize(sample_count * 2)
	var low := 0.0
	for i in range(sample_count):
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
				for click in RELOAD_CLICK_TIMES:
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
		data[i * 2] = pcm & 255
		data[i * 2 + 1] = (pcm >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

func release_voice(voice: Node) -> void:
	var index := voices.find(voice)
	if index < 0:
		return
	voices.remove_at(index)
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
		var pool := idle_spatial if voice is AudioStreamPlayer3D else idle_flat
		if pool.size() < MAX_IDLE_VOICES_PER_TYPE:
			pool.append(voice)
		else:
			voice.queue_free()

func acquire_voice(spatial: bool) -> Node:
	var pool := idle_spatial if spatial else idle_flat
	if not pool.is_empty():
		return pool.pop_back()
	return create_voice(spatial)

func create_voice(spatial: bool) -> Node:
	var player = AudioStreamPlayer3D.new() if spatial else AudioStreamPlayer.new()
	# Pooled players belong to this manager for their entire lifetime.
	# Configure their fixed mixer route once, outside repeated combat events.
	player.bus = bus_name
	add_child(player)
	player.finished.connect(release_voice.bind(player))
	return player

func _exit_tree() -> void:
	vehicle_audio.clear()
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
	voices.clear()
	idle_spatial.clear()
	idle_flat.clear()
	actor_states.clear()
	retired_actor_ids.clear()
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.remove_bus(bus)

func effect(name: String, at: Vector3, spatial := true, gain := 1.0, priority := 1) -> Node:
	if volume <= 0 or not banks.has(name):
		return null
	var reach := PRIORITY_SPATIAL_REACH if priority >= 2 else SPATIAL_REACH
	if spatial and listener.global_position.distance_squared_to(at) > reach * reach:
		return null
	if voices.size() >= MAX_VOICES:
		var victim: Node = null
		var victim_priority := 0
		for voice in voices:
			var voice_priority := int(voice.get_meta("priority"))
			if voice_priority <= priority and (victim == null or voice_priority < victim_priority):
				victim = voice
				victim_priority = voice_priority
		if victim == null:
			return null
		release_voice(victim)
	var player = acquire_voice(spatial)
	var count: int = played_events.get(name, 0)
	player.stream = banks[name][count % banks[name].size()]
	player.set_meta("gain", gain)
	player.set_meta("priority", priority)
	player.set_meta("effect", name)
	var playback_db := linear_to_db(maxf(0.00001, volume * gain))
	if spatial:
		var cutoff_hz := 5000.0
		player.global_position = at
		# Reused voices usually keep their reach and attenuation profile.
		# Avoid resubmitting unchanged audio properties during combat bursts.
		if player.max_distance != reach:
			player.max_distance = reach
		var unit_size := 9.0 if priority >= 2 else 2.0
		if player.unit_size != unit_size:
			player.unit_size = unit_size
		occlusion_query.from = listener.global_position
		occlusion_query.to = at
		var hit := listener.get_world_3d().direct_space_state.intersect_ray(occlusion_query)
		if not hit.is_empty():
			playback_db -= 9
			player.set_meta("gain", gain * db_to_linear(-9))
			cutoff_hz = 1500.0
		if player.attenuation_filter_cutoff_hz != cutoff_hz:
			player.attenuation_filter_cutoff_hz = cutoff_hz
	# Submit the final occlusion values once, including pooled voice resets.
	player.volume_db = playback_db
	voices.append(player)
	played_events[name] = count + 1
	player.play()
	return player

func shot(at: Vector3, kind: int) -> void:
	if kind >= 0 and kind < SHOT_EFFECTS.size():
		effect(SHOT_EFFECTS[kind], at, true, 1, 2)

func feedback(kind: int, killed: bool) -> void:
	effect(("kill" if killed else "hit") if kind == 0 else "hurt", Vector3.ZERO, false, 0.55, 3)

func update_actors(actors: Dictionary, world, camera: Camera3D) -> void:
	if camera == null:
		return
	# Render updates can outnumber camera movement (including aiming pauses).
	# Avoid resubmitting an unchanged listener transform to the audio server.
	# Exact comparison still follows every translation and rotation.
	var camera_transform := camera.global_transform
	if listener.global_transform != camera_transform:
		listener.global_transform = camera_transform
	# Defer removals without copying every actor key each rendered frame.
	retired_actor_ids.clear()
	for id in actor_states:
		if not actors.has(id):
			retired_actor_ids.append(id)
	for id in retired_actor_ids:
		actor_states.erase(id)
	for id in actors:
		var actor = actors[id]
		# Audio queries do not mutate actors; reuse this frame's motion snapshot
		# across stride checks, transitions and retained state writes.
		var actor_position: Vector3 = actor.position
		var actor_velocity: Vector3 = actor.velocity
		var actor_grounded: bool = actor.grounded
		# Action edges and the retained snapshot share one property read.
		# In particular ammo calls a magazine getter on every access.
		var actor_reload: float = actor.reload_left
		var actor_heal: float = actor.heal_left
		var actor_ammo: int = actor.ammo
		var actor_med: int = actor.medkits
		var actor_frags: int = actor.grenades
		var actor_armor: float = actor.armor
		var actor_health: float = actor.health
		var actor_throw: float = actor.throw_left
		var actor_total: int = actor_ammo + actor.reserve
		var step_distance := 0.0
		# One dictionary lookup for existing actors on the per-frame path.
		# Only actor retirement removes entries; stored snapshots are non-null.
		var state: ActorAudioState = actor_states.get(id)
		var has_previous := state != null
		if not has_previous:
			state = ActorAudioState.new()
		if has_previous and actor.alive:
			var previous: ActorAudioState = state
			# Airborne/teleport updates cannot advance footsteps. Keep their
			# jump/landing transitions below without computing planar lengths.
			var continuous_ground: bool = actor_grounded and previous.ground
			# Only threshold comparisons need speed; retain actual distance for
			# accumulated stride. Stationary correction jitter cannot emit steps,
			# so reject it before computing the displacement's square root.
			var speed_squared := Vector2(actor_velocity.x, actor_velocity.z).length_squared() if continuous_ground else 0.0
			var distance := 0.0
			if continuous_ground and speed_squared > 0.2 * 0.2:
				# Stationary and airborne actors never accumulate strides;
				# defer even the displacement subtraction until it is needed.
				var delta: Vector3 = actor_position - previous.position
				distance = Vector2(delta.x, delta.z).length()
			if continuous_ground and speed_squared > 0.2 * 0.2 and distance < 2.0:
				step_distance = previous.distance + distance
				var stride := 1.6 if actor.crouched else (2.6 if speed_squared > 36.0 else 2.2)
				if step_distance >= stride:
					step_distance = fmod(step_distance, stride)
					# Most actor updates emit no sound. Build the emission
					# position only once a footstep or transition needs it.
					var origin: Vector3 = actor_position + Vector3.UP * 0.4
					# Advance stride even when inaudible, but avoid the surface
					# physics ray for sounds effect() would discard anyway.
					if volume > 0 and listener.global_position.distance_squared_to(origin) <= SPATIAL_REACH * SPATIAL_REACH:
						effect(world.footstep_surface(actor_position), origin, true, 0.22 if actor.crouched else (0.85 if speed_squared > 36.0 else 0.55))
			if previous.ground and not actor_grounded and actor_velocity.y > 1:
				effect("jump", actor_position + Vector3.UP * 0.4, true, 0.4)
			if not previous.ground and actor_grounded and previous.vy < -2:
				effect("land", actor_position + Vector3.UP * 0.4, true, clampf(absf(previous.vy) / 12, 0.25, 1))
			if previous.reload <= 0 and actor_reload > 0:
				effect("reload_start", actor.eye_position(), true, 0.55)
			elif previous.reload > 0 and actor_reload <= 0 and actor_ammo > previous.ammo:
				effect("reload_end", actor.eye_position(), true, 0.55)
			if previous.heal <= 0 and actor_heal > 0:
				effect("heal_start", actor.eye_position(), true, 0.4)
			elif previous.heal > 0 and actor_heal <= 0 and actor_health > previous.health:
				effect("heal_end", actor.eye_position(), true, 0.4)
			if previous.throw <= 0 and actor_throw > 0:
				effect("throw", actor.eye_position(), true, 0.4)
			if actor_total > previous.total or actor_med > previous.med or actor_frags > previous.frags or actor_armor > previous.armor:
				effect("pickup", actor.eye_position(), true, 0.4)
		# Read all transitions first, then reuse the retained state object.
		# A fresh snapshot per actor per rendered frame creates avoidable churn.
		state.position = actor_position
		state.ground = actor_grounded
		state.vy = actor_velocity.y
		state.reload = actor_reload
		state.heal = actor_heal
		state.ammo = actor_ammo
		state.total = actor_total
		state.med = actor_med
		state.frags = actor_frags
		state.armor = actor_armor
		state.health = actor_health
		state.throw = actor_throw
		state.distance = step_distance
		# Existing snapshots are retained by reference; only new actors
		# need insertion into the roster after their snapshot is initialized.
		if not has_previous:
			actor_states[id] = state

func reset_round() -> void:
	vehicle_audio.clear()
	actor_states.clear()
	retired_actor_ids.clear()
	for voice in voices.duplicate():
		release_voice(voice)
