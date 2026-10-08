extends SceneTree

class ContextPlayback extends "res://scripts/voice_playback.gd":
	var resets := 0

	func reset() -> void:
		resets += 1
		super.reset()

func _initialize() -> void:
	var voice := ContextPlayback.new()
	assert(voice.valid_context(), "Unbound audio tests remain supported")
	assert(voice.resets == 0)
	voice.game = {"online": true, "running": true, "network_round_id": "one", "match_mode": "duo"}
	assert(voice.valid_context())
	assert(voice.resets == 1)
	for frame in range(18000):
		assert(voice.valid_context())
	assert(voice.resets == 1)
	voice.game.running = false
	assert(not voice.valid_context())
	assert(voice.resets == 1, "Running gates eligibility without changing round identity")
	voice.game.running = true
	voice.game.network_round_id = "two"
	assert(voice.valid_context())
	assert(voice.resets == 2, "New rounds flush old playback")
	voice.game.match_mode = "solo"
	assert(not voice.valid_context())
	assert(voice.resets == 3)
	voice.game.online = false
	assert(not voice.valid_context())
	assert(voice.resets == 4)
	voice.game.online = true
	voice.game.match_mode = "duo"
	voice.game.network_round_id = ""
	assert(not voice.valid_context(), "Online duo still requires a round")
	assert(voice.resets == 5)
	voice.free()
	print("VOICE_PLAYBACK_CONTEXT_PASS unbound stable running round mode offline empty_round")
	quit()
