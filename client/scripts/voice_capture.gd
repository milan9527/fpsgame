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
	if value == transmitting:
		return
	transmitting = value
	pending.clear()
	resampler.reset()
	capture.clear_buffer()
	if value:
		last_tick = Time.get_ticks_msec()
		player.play()
	else:
		player.stop()

func reset_round() -> void:
	set_transmitting(false)
	sequence = 0

func feed(frames: PackedVector2Array) -> void:
	if not transmitting:
		return
	if frames.size() > 8192:
		pending.clear()
		resampler.reset()
		return
	pending.append_array(resampler.push(frames))
	while pending.size() >= Codec.FRAMES:
		if sequence >= 2147483647:
			set_transmitting(false)
			return
		var packet := Codec.encode(pending.slice(0, Codec.FRAMES))
		pending = pending.slice(Codec.FRAMES)
		packet_ready.emit(sequence, packet)
		sequence += 1

func _process(_dt: float) -> void:
	if not transmitting:
		return
	var now := Time.get_ticks_msec()
	var count := capture.get_frames_available()
	if now - last_tick > 150 or count > int(AudioServer.get_mix_rate() * 0.12):
		capture.clear_buffer()
		pending.clear()
		resampler.reset()
	elif count > 0:
		feed(capture.get_buffer(count))
	last_tick = now

func _exit_tree() -> void:
	if player != null:
		player.stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.remove_bus(index)
