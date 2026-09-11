extends SceneTree
const Capture = preload("res://scripts/voice_capture.gd")
const Codec = preload("res://scripts/voice_codec.gd")
var packets: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(AudioServer.get_driver_name() == "PulseAudio", "Must exercise the actual PulseAudio driver")
	assert(OS.get_environment("VOICE_VIRTUAL_DEVICE_TEST") == "1")
	AudioServer.input_device = "Default"
	var source := Capture.new()
	root.add_child(source)
	var master_capture := AudioEffectCapture.new()
	master_capture.buffer_length = 0.25
	var master_effect := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, master_capture)
	source.packet_ready.connect(func(sequence, packet): packets.append([sequence, packet]))
	assert(not source.player.playing)
	source.set_activity(false, true)
	await create_timer(2.0).timeout
	assert(source.last_signal > 0 and source.peak > 0.1 and source.peak < 0.5, "Virtual input must reach AudioStreamMicrophone")
	assert(packets.is_empty() and source.sequence == 0, "Local test cannot transmit")
	master_capture.clear_buffer()
	var playback_id := source.player.get_stream_playback().get_instance_id()
	source.set_activity(true, false)
	assert(source.player.get_stream_playback().get_instance_id() == playback_id, "Mode switch must retain live driver input")
	await create_timer(2.0).timeout
	source.set_activity(false, false)
	assert(packets.size() >= 60 and packets.size() <= 110)
	var energy := 0.0
	var count := 0
	var crossings := 0
	var previous := 0.0
	for i in range(packets.size()):
		assert(packets[i][0] == i)
		var frames := Codec.decode(packets[i][1])
		for frame in frames:
			energy += frame.x * frame.x
			count += 1
			if previous < 0 and frame.x >= 0:
				crossings += 1
			previous = frame.x
	var rms := sqrt(energy / count)
	var frequency := float(crossings) * Codec.RATE / count
	print("VOICE_DEVICE_MEASURE packets=%d rms=%f frequency=%f" % [packets.size(), rms, frequency])
	assert(rms > 0.12 and rms < 0.23)
	assert(frequency > 420 and frequency < 460, "Decoded microphone packets must preserve the 440 Hz fixture")
	var stopped_count := packets.size()
	await create_timer(0.2).timeout
	assert(packets.size() == stopped_count and not source.player.playing)
	assert(master_capture.get_frames_available() > 1000, "Local output check must include actual mixed frames")
	for frame in master_capture.get_buffer(master_capture.get_frames_available()):
		assert(frame.length() < 0.0001, "Microphone must not echo through the local output")
	source.set_transmitting(true)
	await create_timer(1.0).timeout
	print("VOICE_RESTART_INPUT peak=%f signal=%d frames=%d" % [source.peak, source.last_signal, source.capture.get_frames_available()])
	source.set_transmitting(false)
	assert(packets.size() - stopped_count >= 30, "Push-to-talk must resume capturing after release")
	var restart_energy := 0.0
	var restart_samples := 0
	for i in range(stopped_count, packets.size()):
		assert(packets[i][0] == i)
		for frame in Codec.decode(packets[i][1]):
			restart_energy += frame.x * frame.x
			restart_samples += 1
	print("VOICE_RESTART_MEASURE rms=%f packets=%d" % [sqrt(restart_energy / restart_samples), packets.size() - stopped_count])
	assert(sqrt(restart_energy / restart_samples) > 0.12)
	AudioServer.remove_bus_effect(0, master_effect)
	source.queue_free()
	await process_frame
	print("VOICE_DEVICE_PASS driver=PulseAudio virtual_source=440Hz monitoring_no_send=ok captured_packets=%d rms=%f frequency=%f stop=ok restart=ok no_local_echo=ok" % [packets.size(), rms, frequency])
	quit()
