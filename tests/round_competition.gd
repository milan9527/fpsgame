extends SceneTree

func _initialize() -> void:
	# Exercise the production predicate without constructing a world.
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var start := source.find("func round_has_competition()")
	var end := source.find("\nfunc alive_count()", start)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar actors: Dictionary = {}\nvar match_mode := \"solo\"\n" + source.substr(start, end - start)
	assert(script.reload() == OK)
	var probe = script.new()
	var teams = load("res://scripts/team_rules.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55720260929
	var cases := 0
	for sample in range(2000):
		probe.actors.clear()
		var living := 0
		for id in range(sample % 25):
			var alive := rng.randf() > 0.4
			probe.actors[id] = {"alive": alive, "team_id": rng.randi_range(-1, 6)}
			if alive:
				living += 1
		probe.match_mode = "solo"
		assert(probe.round_has_competition() == (living > 1))
		probe.match_mode = "duo"
		assert(probe.round_has_competition() == (teams.living(probe.actors).size() > 1))
		cases += 2
	for team in [-1, 0, 1]:
		probe.actors = {1: {"alive": true, "team_id": team}, 2: {"alive": true, "team_id": team}}
		assert(not probe.round_has_competition())
	probe.actors[2].team_id = 2
	assert(probe.round_has_competition())
	probe.actors[2].alive = false
	assert(not probe.round_has_competition())
	print("ROUND_COMPETITION_PASS randomized=%d same_team_invalid_team_death=ok" % cases)
	quit()
