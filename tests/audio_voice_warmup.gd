extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	sound.warm_voices()
	var count: int = sound.get_child_count()
	sound.warm_voices()
	assert(sound.get_child_count() == count, "Warmup must be idempotent")
	assert(sound.voices.is_empty() and sound.played_events.is_empty())
	for pool in [sound.idle_spatial, sound.idle_flat]:
		assert(pool.size() == sound.MAX_IDLE_VOICES_PER_TYPE)
		for voice in pool:
			assert(not voice.playing and voice.stream == null)
			assert(voice.finished.get_connections().size() == 1)
	for i in range(sound.MAX_IDLE_VOICES_PER_TYPE):
		assert(sound.effect("gun_ar", Vector3.ZERO) != null)
		assert(sound.effect("hit", Vector3.ZERO, false) != null)
	assert(sound.get_child_count() == count, "First overlapping burst must allocate no player nodes")
	assert(sound.voices.size() == sound.MAX_IDLE_VOICES_PER_TYPE * 2)
	sound.reset_round()
	assert(sound.voices.is_empty())
	sound.warm_voices()
	assert(sound.get_child_count() == count)
	sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("PASS silent idempotent warmup, first 32 overlapping sounds without node allocation, reset")
	quit()
