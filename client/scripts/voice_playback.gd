extends Node

const Codec = preload("res://scripts/voice_codec.gd")
const Jitter = preload("res://scripts/voice_jitter.gd")
const MAX_SPEAKERS := 2
var game
var context_initialized := false
var context_online := false
var context_round_id := ""
var context_match_mode := ""
var streams: Dictionary = {}
var muted: Dictionary = {}
var bus_name := ""
var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			reset()
var volume := 0.8:
	set(value):
		var next_volume := clampf(value, 0, 1)
		if next_volume == volume:
			return
		volume = next_volume
		var volume_db := linear_to_db(maxf(0.00001, volume))
		for stream in streams.values():
			stream.player.volume_db = volume_db

func _ready() -> void:
	set_process(not streams.is_empty())
	bus_name = "TeamVoice_" + str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	var limiter := AudioEffectLimiter.new()
	limiter.threshold_db = -3
	limiter.ceiling_db = -1
	AudioServer.add_bus_effect(index, limiter)

func bind(owner_game) -> void:
	game = owner_game
	game.voice_packet_received.connect(receive)

func valid_context() -> bool:
	if game == null:
		return true
	if not context_initialized or context_online != game.online or context_round_id != game.network_round_id or context_match_mode != game.match_mode:
		reset()
		context_online = game.online
		context_round_id = game.network_round_id
		context_match_mode = game.match_mode
		context_initialized = true
	return game.online and game.running and game.match_mode == "duo" and not game.network_round_id.is_empty()

func receive(sender: int, sequence: int, packet: PackedByteArray) -> void:
	if not enabled or sender <= 0 or muted.has(sender) or not valid_context() or not Codec.valid(packet):
		return
	if not streams.has(sender):
		if streams.size() >= MAX_SPEAKERS:
			return
		var player := AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = Codec.RATE
		generator.buffer_length = 0.12
		player.stream = generator
		player.bus = bus_name
		player.volume_db = linear_to_db(maxf(0.00001, volume))
		add_child(player)
		streams[sender] = {"player": player, "jitter": Jitter.new(), "last": Time.get_ticks_msec(), "queued_frames": 0}
		set_process(true)
	var stream: Dictionary = streams[sender]
	var now := Time.get_ticks_msec()
	if stream.jitter.push(sequence, packet, now):
		stream.last = now

func set_muted(sender: int, value: bool) -> void:
	if value:
		muted[sender] = true
		remove_stream(sender)
	else:
		muted.erase(sender)

func remove_stream(sender: int) -> void:
	if streams.has(sender):
		var player: AudioStreamPlayer = streams[sender].player
		player.stop()
		player.queue_free()
		streams.erase(sender)
		if streams.is_empty():
			set_process(false)

func reset() -> void:
	for sender in streams.keys():
		remove_stream(sender)

func _process(_dt: float) -> void:
	if not enabled or not valid_context():
		reset()
		return
	var now := Time.get_ticks_msec()
	for sender in streams.keys():
		var stream: Dictionary = streams[sender]
		if now - stream.last > 500:
			remove_stream(sender)
			continue
		var jitter = stream.jitter
		var player: AudioStreamPlayer = stream.player
		if not player.playing:
			if jitter.next_sequence < 0 or now < jitter.due:
				continue
			player.play()
		var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
		# Keep about 40 ms queued for the audio mixer, without replaying old backlog.
		for _packet in range(3):
			if playback.get_frames_available() < Codec.FRAMES:
				break
			var frames: PackedVector2Array = jitter.pull(now + 40)
			if frames.is_empty():
				break
			playback.push_buffer(frames)
			stream.queued_frames += frames.size()

func _exit_tree() -> void:
	reset()
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.remove_bus(index)
