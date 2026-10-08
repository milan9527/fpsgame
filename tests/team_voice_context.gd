extends SceneTree

class ContextVoice extends "res://scripts/team_voice.gd":
	var resets := 0

	func reset_round() -> void:
		resets += 1

func _initialize() -> void:
	var voice := ContextVoice.new()
	voice.game = {"online": false, "network_round_id": "", "match_mode": "solo", "running": false}
	voice._sync_round_context()
	assert(voice.resets == 1, "Initial context must clear voice state")
	for frame in range(18000):
		voice._sync_round_context()
	assert(voice.resets == 1, "Stable gameplay must not reset playback")
	voice.game.running = true
	voice._sync_round_context()
	assert(voice.resets == 1, "Running alone is not a voice context transition")
	voice.game.online = true
	voice._sync_round_context()
	assert(voice.resets == 2, "Connecting clears stale voice state")
	voice.game.match_mode = "duo"
	voice._sync_round_context()
	assert(voice.resets == 3, "Mode changes clear voice state")
	voice.game.network_round_id = "round-one"
	voice._sync_round_context()
	assert(voice.resets == 4)
	voice.game.network_round_id = "round-two"
	voice._sync_round_context()
	assert(voice.resets == 5, "Consecutive rounds cannot share voice state")
	voice.game.online = false
	voice.game.network_round_id = ""
	voice.game.match_mode = "solo"
	voice._sync_round_context()
	assert(voice.resets == 6, "Leaving online play clears voice state once")
	voice._sync_round_context()
	assert(voice.resets == 6)
	voice.free()
	print("TEAM_VOICE_CONTEXT_PASS initial stable running connect mode new_round leave")
	quit()
