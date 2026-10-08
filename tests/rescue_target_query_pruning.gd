extends SceneTree

class Probe:
	extends "res://scripts/rescue_rules.gd"
	var queries := 0
	func accessible(_game, _actor, other) -> bool:
		queries += 1
		return other.reachable

func _initialize() -> void:
	var rules := Probe.new()
	var actor := {"alive": true, "downed": false, "team_id": 1, "position": Vector3.ZERO}
	var near := {"position": Vector3(1, 0, 0), "reachable": true}
	var far := {"position": Vector3(2, 0, 0), "reachable": true}
	var tied := {"position": Vector3(-1, 0, 0), "reachable": true}
	var blocked := {"position": Vector3(0.5, 0, 0), "reachable": false}
	for candidate in [near, far, tied, blocked]:
		candidate.merge({"alive": true, "downed": true, "team_id": 1})
	var game := {"actors": {1: near, 2: far, 3: tied, 4: blocked}}
	assert(rules.target(game, actor) == near)
	assert(rules.queries == 2, "Farther and tied candidates require no accessibility query")
	rules.queries = 0
	game.actors = {4: blocked, 2: far, 1: near}
	assert(rules.target(game, actor) == near)
	assert(rules.queries == 3, "Blocked nearest candidate must not prune reachable candidates")
	rules.queries = 0
	# Ineligible entries deliberately omit position/accessibility fields.
	game.actors = {
		0: actor,
		1: {"alive": false},
		2: {"alive": true, "downed": false},
		3: {"alive": true, "downed": true, "team_id": 2},
		4: near,
	}
	assert(rules.target(game, actor) == near)
	assert(rules.queries == 1, "Ineligible entries require neither distance nor accessibility")
	game.actors = {4: blocked, 2: far, 1: near}
	near.reachable = false
	far.reachable = false
	assert(rules.target(game, actor) == null)
	print("RESCUE_TARGET_QUERY_PRUNING_PASS")
	quit()
