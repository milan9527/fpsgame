extends SceneTree
const Relay = preload("res://scripts/voice_relay.gd")
const Codec = preload("res://scripts/voice_codec.gd")

func _initialize() -> void:
	var relay := Relay.new()
	var frames := PackedVector2Array()
	frames.resize(Codec.FRAMES)
	var packet := Codec.encode(frames)
	for sequence in range(6):
		assert(relay.accept(10, sequence, packet, 0))
	assert(not relay.accept(10, 6, packet, 0))
	assert(not relay.accept(10, 7, packet, 19))
	assert(relay.accept(10, 8, packet, 20))
	assert(not relay.accept(10, 8, packet, 40))
	assert(not relay.accept(10, 9, PackedByteArray(), 40))
	assert(relay.accept(11, 0, packet, 20), "Senders have independent rate budgets")
	assert(relay.accept(10, 1000, packet, 10000), "A network gap must not permanently lock out valid audio")
	assert(relay.accept(10, 998, packet, 10000), "Recent reordered packets remain usable")
	assert(not relay.accept(10, 998, packet, 10000))
	assert(not relay.accept(10, 935, packet, 10000))
	assert(relay.senders[10].seen.size() <= 64)
	var teams = load("res://scripts/team_rules.gd").new()
	teams.mode = "duo"
	teams.assignments = {10: 1, 11: 1, 12: 2, 13: 2}
	var sessions := {10: {"party_id": "a"}, 11: {"party_id": "a"}, 12: {"party_id": "b"}, 13: {"party_id": "b"}}
	for phase in ["waiting", "lobby", "live", "finished"]:
		assert(relay.recipients(10, phase, sessions, teams) == [11])
		assert(relay.recipients(12, phase, sessions, teams) == [13])
	assert(relay.recipients(99, "live", sessions, teams).is_empty())
	assert(relay.recipients(10, "standby", sessions, teams).is_empty())
	sessions[11].revoking = true
	assert(relay.recipients(10, "live", sessions, teams).is_empty())
	assert(relay.recipients(11, "live", sessions, teams).is_empty())
	sessions[10].party_id = ""
	assert(relay.recipients(10, "lobby", sessions, teams).is_empty())
	relay.reset()
	assert(relay.senders.is_empty() and relay.accept(10, 0, packet, 0))
	print("VOICE_RELAY_PASS rate=50 burst=6 replay=ok packet_bounds=ok session_isolation=ok party_lobby=ok team_battle=ok revoked=ok reset=ok")
	quit()
