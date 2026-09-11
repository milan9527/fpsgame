extends Node

signal packet_ready(sequence: int, packet: PackedByteArray)
const Codec = preload("res://scripts/voice_codec.gd")
const Resampler = preload("res://scripts/voice_resampler.gd")
var sequence := 0
var player: AudioStreamPlayer
var capture: AudioEffectCapture
var resampler
var pending := PackedVector2Array()
var bus_name := ""
var transmitting := false
var monitoring := false
var gain := 1.0
var peak := 0.0
var clipped := false
var last_signal := 0
var last_input := 0
var last_tick := 0

func _ready() -> void:
	bus_name = "Microphone_" + str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	# Capture runs before bus mute: microphone never feeds the local speakers.
	AudioServer.set_bus_mute(index, true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.2
	AudioServer.add_bus_effect(index, capture)
	player = AudioStreamPlayer.new()
	player.stream = AudioStreamMicrophone.new()
	player.bus = bus_name
	add_child(player)
	resampler = Resampler.new(int(AudioServer.get_mix_rate()))

func set_transmitting(value: bool) -> void:
	set_activity(value, false)

func set_activity(send: bool, monitor: bool) -> void:
	if send == transmitting and monitor == monitoring:
		return
	transmitting = send
	monitoring = monitor
	peak = 0
	clipped = false
	last_signal = 0
	last_input = 0
	pending.clear()
	resampler.reset()
	capture.clear_buffer()
	if transmitting or monitoring:
		last_tick = Time.get_ticks_msec()
		player.play()
	else:
		player.stop()

func reset_round() -> void:
	set_transmitting(false)
	sequence = 0

func feed(frames: PackedVector2Array) -> void:
	if not transmitting and not monitoring:
		return
	if frames.size() > 8192:
		pending.clear()
		resampler.reset()
		peak = 0
		clipped = false
		last_signal = 0
		return
	var adjusted := PackedVector2Array()
	last_input = Time.get_ticks_msec()
	peak = 0
	clipped = false
	for frame in frames:
		var value := (frame.x + frame.y) * 0.5
		value = value * clampf(gain, 0.25, 4.0) if is_finite(value) else 0.0
		peak = maxf(peak, absf(value))
		clipped = clipped or absf(value) >= 0.99
		adjusted.append(Vector2.ONE * clampf(value, -1.0, 1.0))
	peak = minf(peak, 1.0)
	if peak > 0.005:
		last_signal = Time.get_ticks_msec()
	if not transmitting:
		return
	pending.append_array(resampler.push(adjusted))
	while pending.size() >= Codec.FRAMES:
		if sequence >= 2147483647:
			set_transmitting(false)
			return
		var packet := Codec.encode(pending.slice(0, Codec.FRAMES))
		pending = pending.slice(Codec.FRAMES)
		packet_ready.emit(sequence, packet)
		sequence += 1

func _process(_dt: float) -> void:
	if not transmitting and not monitoring:
		return
	var now := Time.get_ticks_msec()
	var count := capture.get_frames_available()
	if now - last_tick > 150 or count > int(AudioServer.get_mix_rate() * 0.12):
		capture.clear_buffer()
		pending.clear()
		resampler.reset()
		peak = 0
		clipped = false
		last_signal = 0
	elif count > 0:
		feed(capture.get_buffer(count))
	elif now - last_input > 100:
		peak = 0
		clipped = false
	last_tick = now

func _exit_tree() -> void:
	if player != null:
		player.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.remove_bus(index)
