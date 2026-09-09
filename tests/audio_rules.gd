extends SceneTree

var sound
var recorder: AudioEffectRecord
var output_root := ""

func _initialize() -> void:
	call_deferred("run")

func recorded_pan(at: Vector3, name: String) -> Vector2:
	sound.reset_round()
	recorder.set_recording_active(true)
	sound.effect("gun_ar", at, true, 1, 2)
	await create_timer(0.4).timeout
	recorder.set_recording_active(false)
	var recording := recorder.get_recording()
	assert(recording != null and recording.stereo and recording.data.size() > 1000, "Audio engine produces stereo PCM")
	var energy := Vector2.ZERO
	for offset in range(0, recording.data.size() - 3, 4):
		energy.x += float(recording.data.decode_s16(offset)) ** 2
		energy.y += float(recording.data.decode_s16(offset + 2)) ** 2
	assert(energy.x + energy.y > 10000, "Recorded output is audible, not silence")
	assert(recording.save_to_wav(output_root.path_join("audio-" + name + ".wav")) == OK)
	return energy

func run() -> void:
	output_root = OS.get_environment("AUDIO_ARTIFACT_DIR")
	if output_root == "":
		output_root = ProjectSettings.globalize_path("user://audio-verification")
	assert(DirAccess.make_dir_recursive_absolute(output_root) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	sound = game.sound
	sound.volume = 1
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.01, 20)
	actor.velocity = Vector3.ZERO
	actor.grounded = true
	for i in range(2):
		await physics_frame
	var roster := {1: actor}
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.is_empty(), "Initial snapshots do not replay historical actions")
	assert(game.world.footstep_surface(Vector3(0, 0, 20)) == "step_hard")
	assert(game.world.footstep_surface(Vector3(-20, 0, 20)) == "step_grass")
	actor.velocity.z = -5.5
	for i in range(3):
		actor.position.z -= 1
		sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("step_hard", 0) == 1)
	actor.velocity.z = 0
	for i in range(20):
		actor.position.x += 0.1 if i % 2 == 0 else -0.1
		sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.step_hard == 1, "Standing correction jitter cannot repeat footsteps")
	actor.position.x += 30
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.step_hard == 1, "Position discontinuity does not emit steps")
	actor.velocity.z = -9
	actor.sprint = false
	for i in range(3):
		actor.position.z -= 1
		sound.update_actors(roster, game.world, actor.camera)
	assert(is_equal_approx(sound.voices.back().get_meta("gain"), 0.85), "Replicated velocity determines sprint loudness without a local sprint flag")
	actor.crouched = true
	actor.velocity.z = -2.8
	for i in range(2):
		actor.position.z -= 1
		sound.update_actors(roster, game.world, actor.camera)
	assert(is_equal_approx(sound.voices.back().get_meta("gain"), 0.22), "Crouched steps are quieter")
	actor.crouched = false
	actor.velocity.z = 0
	actor.grounded = false
	actor.velocity.y = 7.5
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("jump", 0) == 1)
	actor.velocity.y = -8
	sound.update_actors(roster, game.world, actor.camera)
	actor.grounded = true
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("land", 0) == 1)
	actor.ammo = 0
	actor.reload_left = 2
	sound.update_actors(roster, game.world, actor.camera)
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("reload_start", 0) == 1)
	actor.reload_left = 0
	actor.ammo = 30
	actor.reserve -= 30
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("reload_end", 0) == 1)
	assert(sound.played_events.get("pickup", 0) == 0, "Reload transfer is not a pickup")
	actor.heal_left = 3.5
	actor.health = 30
	sound.update_actors(roster, game.world, actor.camera)
	actor.heal_left = 0
	actor.health = 20
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("heal_end", 0) == 0, "Interrupted healing has no success cue")
	actor.heal_left = 3.5
	sound.update_actors(roster, game.world, actor.camera)
	actor.heal_left = 0
	actor.health = 85
	actor.medkits -= 1
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("heal_end", 0) == 1)
	actor.reserve += 45
	sound.update_actors(roster, game.world, actor.camera)
	assert(sound.played_events.get("pickup", 0) == 1)
	sound.reset_round()
	assert(sound.voices.is_empty() and sound.actor_states.is_empty())
	for i in range(sound.MAX_VOICES - 1):
		sound.effect("gun_ar", actor.eye_position(), true, 1, 2)
	var quiet: Node = sound.effect("step_hard", actor.eye_position())
	sound.effect("gun_ar", actor.eye_position(), true, 1, 2)
	assert(not sound.voices.has(quiet), "Higher priority sounds reclaim the quietest-priority voice first")
	for i in range(70):
		sound.effect("gun_ar", actor.eye_position(), true, 1, 2)
	assert(sound.voices.size() == sound.MAX_VOICES)
	assert(sound.effect("step_hard", actor.eye_position()) == null, "Quiet footsteps cannot displace a full bank of gunshots")
	sound.volume = 0
	for voice in sound.voices:
		assert(voice.volume_db <= -99)
	assert(sound.effect("hit", Vector3.ZERO, false) == null)
	sound.reset_round()
	sound.volume = 1
	# Each original waveform has bounded 16-bit samples and a quiet ending.
	for bank in sound.banks.values():
		for stream in bank:
			var peak := 0
			for offset in range(0, stream.data.size(), 2):
				peak = maxi(peak, absi(stream.data.decode_s16(offset)))
			assert(peak > 100 and peak <= 24000)
			assert(absi(stream.data.decode_s16(stream.data.size() - 2)) < 1000)
	assert(sound.banks.step_hard[0].data != sound.banks.step_hard[1].data)
	var preview := AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.mix_rate = sound.RATE
	var sequence := PackedByteArray()
	var gap := PackedByteArray()
	gap.resize(sound.RATE / 2)
	gap.fill(0)
	for name in ["step_grass", "step_hard", "land", "reload_start", "reload_end", "heal_end", "pickup", "explosion"]:
		sequence.append_array(sound.banks[name][0].data)
		sequence.append_array(gap)
	preview.data = sequence
	assert(preview.save_to_wav(output_root.path_join("audio-actions.wav")) == OK)
	# Real engine mixing verifies stereo direction and listener orientation.
	sound.listener.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 20))
	var open_voice: Node = sound.effect("gun_ar", Vector3(8, 1.6, 18), true, 1, 2)
	var open_db: float = open_voice.volume_db
	var wall = game.world.block(Vector3(4, 1.6, 19), Vector3(0.3, 4, 4), "465a61")
	await physics_frame
	await physics_frame
	var blocked: Node = sound.effect("gun_ar", Vector3(8, 1.6, 18), true, 1, 2)
	assert(blocked.volume_db < open_db - 8 and blocked.attenuation_filter_cutoff_hz == 1500, "Wall muffles direct sound")
	wall.queue_free()
	await physics_frame
	await physics_frame
	recorder = AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0, recorder)
	var right: Vector2 = await recorded_pan(Vector3(8, 1.6, 18), "right")
	assert(right.y > right.x * 1.2, "Source on the right is louder in right channel")
	sound.listener.rotation.y = PI
	var left: Vector2 = await recorded_pan(Vector3(8, 1.6, 18), "turned")
	assert(left.x > left.y * 1.2, "Turning listener reverses stereo direction")
	sound.reset_round()
	recorder.set_recording_active(true)
	for i in range(48):
		sound.effect("gun_ar", Vector3.ZERO, false, 1, 2)
	await create_timer(0.3).timeout
	recorder.set_recording_active(false)
	var overloaded := recorder.get_recording()
	var peak := 0
	for offset in range(0, overloaded.data.size(), 2):
		peak = maxi(peak, absi(overloaded.data.decode_s16(offset)))
	assert(peak > 10000 and peak < 32000, "SFX limiter prevents digital clipping under 48 simultaneous shots")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	actor.apply_damage(10000)
	game.spectator.update_view(game.actors, 1, "live")
	sound.update_actors(game.actors, game.world, game.spectator.camera)
	assert(sound.listener.global_position.is_equal_approx(game.spectator.camera.global_position))
	game.leave()
	assert(sound.voices.is_empty() and sound.actor_states.is_empty())
	print("AUDIO_RULES_PASS surfaces=ok steps=ok jump_land=ok action_edges=ok voice_cap=ok priority=ok occlusion=ok mute=ok pcm=ok stereo=ok limiter=ok spectator_listener=ok cleanup=ok")
	game.request_quit()
