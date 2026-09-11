extends RefCounted

const LIFETIME := 20.0
var markers: Dictionary = {}
var sequences: Dictionary = {}
var next_allowed: Dictionary = {}

func reset() -> void:
	markers.clear()
	sequences.clear()
	next_allowed.clear()

func submit(id: int, sequence: int, point: Vector2, clear: bool, now: float, actors: Dictionary, teams) -> bool:
	if teams.mode != "duo" or not actors.has(id) or not actors[id].alive or actors[id].team_id <= 0:
		return false
	var previous: int = sequences.get(id, 0)
	if sequence <= previous or sequence > previous + 64 or not point.is_finite() or absf(point.x) > 115 or absf(point.y) > 115:
		return false
	sequences[id] = sequence
	if clear:
		markers.erase(id)
		return true
	if now < next_allowed.get(id, 0.0):
		return false
	next_allowed[id] = now + 1.0
	markers[id] = {"id": id, "point": point, "expires": now + LIFETIME}
	return true

func visible_for(id: int, now: float, actors: Dictionary, teams) -> Array:
	var result: Array = []
	for sender in markers.keys():
		var marker: Dictionary = markers[sender]
		if marker.expires <= now or not actors.has(sender) or not actors[sender].alive:
			markers.erase(sender)
			continue
		if teams.mode == "duo" and (sender == id or teams.friendly(id, sender)):
			result.append({"id": sender, "point": marker.point, "name": actors[sender].display_name, "remaining": marker.expires - now})
	return result
