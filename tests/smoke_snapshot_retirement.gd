extends SceneTree

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var start := source.find("func smoke_snapshot(")
	var end := source.find("\nfunc update_smoke_visuals", start)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar dedicated = false\nvar network_round_id = 'current'\nvar smoke_clouds = {}\n" + source.substr(start, end - start)
	assert(script.reload() == OK)
	var probe = script.new()
	var states := [
		{"id": 1, "p": Vector3.ZERO, "age": 2.0},
		{"id": 2, "p": Vector3.ONE, "age": 3.0},
		{"id": 3, "p": Vector3.UP, "age": 4.0},
	]
	for sample in range(120):
		probe.smoke_snapshot("current", states, [1, 2, 3])
	assert(probe.smoke_clouds.size() == 3)
	# A partial packet retains clouds listed in the full roster.
	probe.smoke_snapshot("current", [{"id": 2, "p": Vector3.UP, "age": 5.0}], [1, 2, 3])
	assert(probe.smoke_clouds.size() == 3 and probe.smoke_clouds[2].age == 5.0)
	probe.smoke_snapshot("current", [], [2])
	assert(probe.smoke_clouds.size() == 1 and probe.smoke_clouds[2].p == Vector3.UP)
	probe.smoke_snapshot("old", states, [1, 2, 3])
	assert(probe.smoke_clouds.size() == 1)
	probe.dedicated = true
	probe.smoke_snapshot("current", [], [])
	assert(probe.smoke_clouds.size() == 1)
	probe.dedicated = false
	probe.smoke_snapshot("current", [], [])
	probe.smoke_snapshot("current", [], [])
	assert(probe.smoke_clouds.is_empty())
	print("SMOKE_SNAPSHOT_RETIREMENT_PASS stable partial_packet removal stale_round dedicated empty")
	quit()
