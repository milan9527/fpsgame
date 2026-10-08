extends SceneTree

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var start := source.find("func update_smoke_visuals()")
	var end := source.find("\nfunc apply_landing", start)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	var method := source.substr(start, end - start)
	var submission := 'visual.material_override.set_shader_parameter("density", density)'
	assert(method.contains(submission))
	method = method.replace(submission, submission + "\n\t\t\tdensity_submissions += 1")
	script.source_code = "extends Node3D\nconst SmokeRules = preload('res://scripts/smoke_rules.gd')\nvar dedicated = false\nvar smoke_clouds = {}\nvar smoke_visuals = {}\nvar smoke_mesh\nvar density_submissions = 0\n" + method
	assert(script.reload() == OK)
	var probe = script.new()
	probe.update_smoke_visuals()
	probe.smoke_clouds = {1: {"age": 1.0, "p": Vector3.ZERO}, 2: {"age": 3.0, "p": Vector3.ONE}, 3: {"age": 19.0, "p": Vector3.UP}}
	probe.update_smoke_visuals()
	assert(probe.smoke_visuals.size() == 3)
	assert(probe.density_submissions == 3)
	var first = probe.smoke_visuals[1]
	var survivor = probe.smoke_visuals[2]
	var last = probe.smoke_visuals[3]
	for frame in range(120):
		probe.update_smoke_visuals()
	assert(probe.density_submissions == 3)
	assert(not first.is_queued_for_deletion() and not survivor.is_queued_for_deletion())
	probe.smoke_clouds.erase(1)
	probe.smoke_clouds.erase(3)
	probe.update_smoke_visuals()
	assert(first.is_queued_for_deletion() and last.is_queued_for_deletion())
	assert(probe.smoke_visuals.size() == 1 and probe.smoke_visuals[2] == survivor)
	assert(not survivor.is_queued_for_deletion())
	assert(survivor.scale == Vector3.ONE * 6.0)
	# Replaced network snapshots and backwards age corrections must not leave
	# the retained material at its previous fading density.
	for age in [-1.0, 0.0, 1.5, 15.9, 16.0, 17.0, 19.0, 20.0, 3.0]:
		probe.smoke_clouds = {2: {"age": age, "p": Vector3.ONE}}
		probe.update_smoke_visuals()
		var expected: float = script.SmokeRules.density(age)
		assert(survivor.material_override.get_shader_parameter("density") == expected)
		assert(survivor.get_meta(&"smoke_density") == expected)
		assert(survivor.material_override.get_shader_parameter("age") == age)
	probe.smoke_clouds.clear()
	probe.update_smoke_visuals()
	assert(probe.smoke_visuals.is_empty() and survivor.is_queued_for_deletion())
	probe.update_smoke_visuals()
	probe.free()
	print("SMOKE_VISUAL_RETIREMENT_PASS creation steady simultaneous_expiry survivor density_snapshot_rewind final_cleanup")
	quit()
