extends SceneTree

const Pings = preload("res://scripts/team_pings.gd")

class Teams:
	extends RefCounted
	var mode := "duo"
	func friendly(a: int, b: int) -> bool:
		return a % 2 == b % 2

func reference(markers: Dictionary, id: int, now: float, actors: Dictionary, teams) -> Array:
	var result: Array = []
	for sender in markers.keys():
		var marker: Dictionary = markers[sender]
		if marker.expires <= now or not actors.has(sender) or not actors[sender].alive:
			markers.erase(sender)
			continue
		if teams.mode == "duo" and (sender == id or teams.friendly(id, sender)):
			result.append({"id": sender, "point": marker.point, "name": actors[sender].display_name, "remaining": marker.expires - now})
	return result

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 559
	var teams := Teams.new()
	for trial in 2000:
		var pings = Pings.new()
		var actors: Dictionary = {}
		teams.mode = "solo" if trial % 3 == 0 else "duo"
		for sender in rng.randi_range(0, 32):
			pings.markers[sender] = {"id": sender, "point": Vector2(sender, -sender), "expires": float(rng.randi_range(0, 20))}
			if rng.randf() > 0.2:
				actors[sender] = {"alive": rng.randf() > 0.3, "display_name": str(sender)}
		var expected_markers: Dictionary = pings.markers.duplicate(true)
		for now in [10.0, 10.0, 20.0, 21.0]:
			var expected := reference(expected_markers, 1, now, actors, teams)
			var actual: Array = pings.visible_for(1, now, actors, teams)
			assert(actual == expected, "visibility/order mismatch trial %d" % trial)
			assert(pings.markers == expected_markers, "expiry mismatch trial %d" % trial)
	print("TEAM_PING_ITERATION_PASS 2000 randomized cases, repeated expiry, dead/missing actors, team privacy and order")
	quit()
