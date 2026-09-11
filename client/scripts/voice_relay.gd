extends RefCounted

const Codec = preload("res://scripts/voice_codec.gd")
const RATE := 50.0
const BURST := 6.0
var senders: Dictionary = {}

func reset() -> void:
	senders.clear()

func recipients(sender: int, phase: String, sessions: Dictionary, teams) -> Array:
	var targets: Array = []
	if not sessions.has(sender) or sessions[sender].get("revoking", false):
		return targets
	for id in sessions:
		if id == sender or sessions[id].get("revoking", false):
			continue
		if phase in ["waiting", "lobby"]:
			var party: String = sessions[sender].get("party_id", "")
			if not party.is_empty() and party == sessions[id].get("party_id", ""):
				targets.append(id)
		elif phase in ["live", "finished"] and teams.friendly(sender, id):
			targets.append(id)
	return targets

func accept(sender: int, sequence: int, packet: PackedByteArray, now: int) -> bool:
	if sequence < 0 or sequence > 2147483647 or not Codec.valid(packet):
		return false
	var state: Dictionary = senders.get(sender, {"sequence": -1, "seen": {}, "at": now, "tokens": BURST})
	if sequence <= state.sequence - 64 or state.seen.has(sequence):
		return false
	state.tokens = minf(BURST, state.tokens + maxf(0, now - state.at) * RATE / 1000.0)
	state.at = now
	state.sequence = maxi(state.sequence, sequence)
	state.seen[sequence] = true
	for old in state.seen.keys():
		if old <= state.sequence - 64:
			state.seen.erase(old)
	senders[sender] = state
	if state.tokens < 1.0:
		return false
	state.tokens -= 1.0
	return true
