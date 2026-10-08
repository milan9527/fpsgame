extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	var blocked = sound.effect("gun_ar", Vector3.ZERO, true, 0.4, 2)
	var original_id: int = blocked.get_instance_id()
	blocked.attenuation_filter_cutoff_hz = 1500
	sound.release_voice(blocked)
	sound.release_voice(blocked)
	assert(sound.idle_spatial.size() == 1, "Duplicate release must not duplicate a pool entry")
	var open = sound.effect("step_grass", Vector3.ZERO)
	assert(open.get_instance_id() == original_id)
	assert(open.attenuation_filter_cutoff_hz == 5000.0)
	assert(open.unit_size == 2 and open.max_distance == sound.SPATIAL_REACH)
	assert(open.get_meta("gain") == 1.0 and open.get_meta("priority") == 1)
	assert(open.finished.get_connections().size() == 1)
	# Exercise both profile transitions and steady reuse of each profile.
	sound.release_voice(open)
	for priority in [1, 1, 2, 2, 1]:
		var reused = sound.effect("gun_ar", Vector3.ZERO, true, 1.0, priority)
		assert(reused.get_instance_id() == original_id)
		assert(reused.max_distance == (sound.PRIORITY_SPATIAL_REACH if priority >= 2 else sound.SPATIAL_REACH))
		assert(reused.unit_size == (9.0 if priority >= 2 else 2.0))
		assert(reused.attenuation_filter_cutoff_hz == 5000.0)
		sound.release_voice(reused)
	var ui = sound.effect("hit", Vector3.ZERO, false, 0.55, 3)
	assert(ui is AudioStreamPlayer)
	sound.reset_round()
	assert(sound.voices.is_empty())
	assert(sound.idle_flat.size() == 1)
	# A stolen player can be reused immediately; protect the other active voices.
	for i in range(sound.MAX_VOICES - 1):
		sound.effect("gun_ar", Vector3.ZERO, true, 1, 2)
	var protected_voices: Array = sound.voices.duplicate()
	var quiet = sound.effect("step_hard", Vector3.ZERO)
	var replacement = sound.effect("gun_ar", Vector3.ZERO, true, 1, 2)
	assert(replacement == quiet, "Priority stealing reuses the released player")
	assert(replacement.get_meta("effect") == "gun_ar" and replacement.get_meta("priority") == 2)
	for voice in protected_voices:
		assert(sound.voices.has(voice) and voice != replacement)
	assert(sound.voices.size() == sound.MAX_VOICES)
	sound.reset_round()
	# Equal priorities keep the original oldest-first tie break.
	for i in range(sound.MAX_VOICES):
		sound.effect("gun_ar", Vector3.ZERO, true, 1, 2)
	var oldest: Node = sound.voices[0]
	var second_oldest: Node = sound.voices[1]
	assert(sound.effect("gun_sg", Vector3.ZERO, true, 1, 2) == oldest)
	assert(sound.effect("gun_sr", Vector3.ZERO, true, 1, 2) == second_oldest)
	sound.reset_round()
	# Repeated overlapping bursts must preserve the active limit and priority rules.
	for i in range(100):
		sound.effect("explosion", Vector3.ZERO, true, 1, 3)
	assert(sound.voices.size() == sound.MAX_VOICES)
	assert(sound.effect("step_hard", Vector3.ZERO) == null)
	sound.reset_round()
	assert(sound.idle_spatial.size() == sound.MAX_IDLE_VOICES_PER_TYPE)
	await process_frame
	var count_before: int = sound.get_child_count()
	for i in range(1000):
		var voice = sound.effect("gun_ar", Vector3.ZERO)
		sound.release_voice(voice)
	assert(sound.get_child_count() == count_before, "Steady sequential shots allocate no nodes")
	sound.effect("hit", Vector3.ZERO, false)
	for i in range(20):
		if sound.voices.is_empty():
			break
		await create_timer(0.1).timeout
	assert(sound.voices.is_empty(), "Natural finish returns a reused player to its pool")
	sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS audio reuse: filter/gain/reach reset, priority, bounded pools, 1000 allocation-free shots, natural finish")
	quit()
