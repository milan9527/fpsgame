extends SceneTree
const Voice = preload("res://scripts/voice_playback.gd")
const Codec = preload("res://scripts/voice_codec.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var buses := AudioServer.bus_count
	var voice := Voice.new()
	root.add_child(voice)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(voice.bus_name), capture)
	var frames := PackedVector2Array()
	for i in range(Codec.FRAMES):
		frames.append(Vector2.ONE * 0.25 * sin(TAU * 400 * i / Codec.RATE))
	var packet := Codec.encode(frames)
	voice.receive(7, 0, packet)
	assert(voice.streams.is_empty(), "Playback defaults to disabled")
	voice.enabled = true
	for sequence in range(30):
		voice.receive(7, sequence, packet)
		await create_timer(0.02).timeout
	assert(voice.streams.has(7))
	assert(voice.streams[7].queued_frames >= 3200)
	var output := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	for frame in output:
		energy += frame.length_squared() / 2.0
	assert(output.size() > 1000)
	var rms := sqrt(energy / output.size())
	assert(rms > 0.03 and rms < 0.3, "Actual mixer output must contain the decoded tone")
	voice.set_muted(7, true)
	assert(voice.streams.is_empty())
	voice.receive(7, 30, packet)
	assert(voice.streams.is_empty())
	await create_timer(0.2).timeout
	capture.clear_buffer()
	await create_timer(0.15).timeout
	output = capture.get_buffer(capture.get_frames_available())
	for frame in output:
		assert(frame.length() < 0.0001, "Mute must stop queued audio")
	voice.set_muted(7, false)
	voice.receive(7, 31, packet)
	assert(voice.streams.has(7))
	await create_timer(0.6).timeout
	assert(voice.streams.is_empty(), "Inactive speakers are removed")
	voice.receive(7, 100, packet)
	voice.enabled = false
	assert(voice.streams.is_empty())
	voice.queue_free()
	await process_frame
	assert(AudioServer.bus_count == buses, "Voice bus must be released")
	print("VOICE_PLAYBACK_PASS mixer_rms=%f default_disabled=ok mute_flush=ok inactivity=ok bus_cleanup=ok" % rms)
	quit()
