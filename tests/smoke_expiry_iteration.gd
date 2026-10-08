extends SceneTree

func _initialize() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var start := source.find("func advance_grenades(dt: float)")
	var end := source.find("\nfunc explosion_visible", start)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nconst SmokeRules = preload('res://scripts/smoke_rules.gd')\nvar smoke_clouds = {}\nvar grenades = {}\nvar detonated = []\nfunc detonate_grenade(id):\n\tdetonated.append(id)\n\tgrenades.erase(id)\n" + source.substr(start, end - start)
	assert(script.reload() == OK)
	var probe = script.new()
	probe.advance_grenades(0.1)
	probe.smoke_clouds = {1: {"age": 19.9}, 2: {"age": 19.9}, 3: {"age": 1.0}}
	probe.grenades = {4: {"fuse": 0.05}, 5: {"fuse": 1.0}}
	probe.advance_grenades(0.2)
	assert(probe.smoke_clouds.size() == 1 and probe.smoke_clouds.has(3))
	assert(is_equal_approx(probe.smoke_clouds[3].age, 1.2))
	assert(probe.detonated == [4] and probe.grenades.has(5))
	probe.advance_grenades(20.0)
	assert(probe.smoke_clouds.is_empty() and probe.grenades.is_empty())
	probe.smoke_clouds = {6: {"age": 19.9}, 7: {"age": 1.0}}
	probe.advance_grenades(0.2)
	assert(probe.smoke_clouds.size() == 1 and probe.smoke_clouds.has(7))
	assert(is_equal_approx(probe.smoke_clouds[7].age, 1.2))
	probe.advance_grenades(20.0)
	assert(probe.smoke_clouds.is_empty())
	# Several fuses expiring together must preserve insertion order, without
	# skipping the still-flying grenade between them.
	probe.detonated.clear()
	probe.grenades = {8: {"fuse": 0.1}, 9: {"fuse": 2.0}, 10: {"fuse": 0.1}}
	probe.advance_grenades(0.2)
	assert(probe.detonated == [8, 10])
	assert(probe.grenades.size() == 1 and is_equal_approx(probe.grenades[9].fuse, 1.8))
	probe.advance_grenades(0.1)
	assert(probe.detonated == [8, 10] and is_equal_approx(probe.grenades[9].fuse, 1.7))
	print("SMOKE_EXPIRY_ITERATION_PASS empty simultaneous_expiry survivor grenade_detonation smoke_without_grenades simultaneous_detonation flight")
	quit()
