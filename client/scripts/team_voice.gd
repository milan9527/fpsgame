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
	var speaking: bool = eligible and game.ui.voice_microphone and not game.ui.pause_panel.visible and not game.ui.controls.visible and not game.ui.inventory.visible and not game.ui.tactical_map.visible and DisplayServer.window_is_focused() and Input.is_action_pressed("push_to_talk")
	microphone.set_transmitting(speaking)
	game.ui.voice_indicator.text = "TEAM MIC • TRANSMITTING" if speaking else ""
