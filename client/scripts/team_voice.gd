extends Node

var game
var receiver
var microphone
var context := ""

func bind(owner_game) -> void:
	game = owner_game
	receiver = preload("res://scripts/voice_playback.gd").new()
	add_child(receiver)
	receiver.bind(game)
	microphone = preload("res://scripts/voice_capture.gd").new()
	add_child(microphone)
	microphone.packet_ready.connect(send_packet)

func reset_round() -> void:
	receiver.reset()
	receiver.muted.clear()
	microphone.reset_round()

func send_packet(sequence: int, packet: PackedByteArray) -> void:
	if game.online and game.running and game.match_mode == "duo" and not game.network_round_id.is_empty():
		game.submit_voice.rpc_id(1, game.network_round_id, sequence, packet)

func _process(_dt: float) -> void:
	if game == null:
		return
	var current: String = str(game.online) + "/" + game.network_round_id + "/" + game.match_mode
	if current != context:
		reset_round()
		context = current
	receiver.enabled = game.ui.voice_listen
	receiver.volume = game.ui.voice_volume * game.ui.volume
	var eligible: bool = game.online and game.running and game.match_mode == "duo" and not game.network_round_id.is_empty()
	var setup = game.ui.voice_setup
	if AudioServer.input_device != setup.device:
		microphone.set_activity(false, false)
		AudioServer.input_device = setup.device
		# Drivers may reject a disconnected device; reflect the actual fallback.
		setup.device = AudioServer.input_device
	var focused := DisplayServer.window_is_focused()
	if not focused:
		setup.testing = false
	var speaking: bool = eligible and game.ui.voice_microphone and not game.ui.pause_panel.visible and not setup.visible and not game.ui.controls.visible and not game.ui.inventory.visible and not game.ui.tactical_map.visible and focused and Input.is_action_pressed("push_to_talk")
	var testing: bool = setup.visible and game.ui.pause_panel.visible and setup.testing and focused
	microphone.gain = setup.gain
	microphone.set_activity(speaking, testing)
	setup.update_level(microphone.peak, microphone.clipped, testing, microphone.last_signal)
	if not speaking:
		game.ui.voice_indicator.text = ""
	elif microphone.clipped:
		game.ui.voice_indicator.text = "TEAM MIC • CLIPPING — REDUCE INPUT GAIN"
	elif microphone.last_signal > 0 and Time.get_ticks_msec() - microphone.last_signal < 1000:
		game.ui.voice_indicator.text = "TEAM MIC • INPUT DETECTED"
	else:
		game.ui.voice_indicator.text = "TEAM MIC • NO INPUT DETECTED"
