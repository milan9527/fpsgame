extends SceneTree
const Capture = preload("res://scripts/voice_capture.gd")
const Codec = preload("res://scripts/voice_codec.gd")
var packets: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var buses := AudioServer.bus_count
	var source := Capture.new()
	root.add_child(source)
	source.set_process(false)
	source.packet_ready.connect(func(sequence, packet): packets.append([sequence, packet]))
	assert(not source.transmitting and not source.player.playing)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(source.bus_name)))
	var frames := PackedVector2Array()
	var rate := int(AudioServer.get_mix_rate())
	for i in range(rate / 10):
		frames.append(Vector2.ONE * 0.25 * sin(TAU * 400 * i / rate))
	source.feed(frames)
	assert(packets.is_empty(), "Disabled microphone must not emit audio")
	# Synthetic injection exercises conversion/packetization without opening a device.
	source.transmitting = true
	source.feed(frames)
	assert(packets.size() == 4)
	for i in range(packets.size()):
		assert(packets[i][0] == i and Codec.valid(packets[i][1]))
	source.set_transmitting(false)
	assert(source.pending.is_empty())
	source.transmitting = true
	source.feed(frames)
	assert(packets.size() == 8 and packets[4][0] == 4, "PTT bursts must preserve sequence")
	var backlog := PackedVector2Array()
	backlog.resize(8193)
	source.feed(backlog)
	assert(source.pending.is_empty() and packets.size() == 8)
	source.last_tick = Time.get_ticks_msec() - 1000
	source._process(1.0)
	assert(source.pending.is_empty())
	source.reset_round()
	assert(source.sequence == 0 and not source.transmitting)
	# Monitor mode never encodes, increments sequence or transmits test audio.
	source.monitoring = true
	source.gain = 4.0
	var loud := PackedVector2Array([Vector2.ONE * 0.4, Vector2(INF, NAN)])
	source.feed(loud)
	assert(source.peak == 1.0 and source.clipped and source.last_signal > 0)
	assert(packets.size() == 8 and source.sequence == 0 and source.pending.is_empty())
	source.last_input = Time.get_ticks_msec() - 200
	source.last_tick = Time.get_ticks_msec()
	source._process(0.02)
	assert(source.peak == 0 and not source.clipped, "Disconnected input cannot leave stale clipping meter")
	source.gain = 0.5
	source.feed(PackedVector2Array([Vector2.ONE * 0.4]))
	assert(is_equal_approx(source.peak, 0.2) and not source.clipped)
	source.feed(PackedVector2Array([Vector2.ZERO, Vector2(INF, NAN)]))
	assert(source.peak == 0 and not source.clipped)
	source.reset_round()
	assert(not source.monitoring and source.peak == 0)
	source.queue_free()
	await process_frame
	assert(AudioServer.bus_count == buses)
	print("VOICE_CAPTURE_PASS synthetic_only=ok default_off=ok no_local_echo=ok ptt_sequence=ok backlog_discard=ok round_reset=ok monitor_no_send=ok input_gain=ok clipping=ok nonfinite=ok")
	quit()
