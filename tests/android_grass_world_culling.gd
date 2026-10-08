extends SceneTree

# Real OpenGL transforms, production Android assets, no resource baking.
# Counts culling decisions; these are not device frame-time measurements.
const Mobile = preload("res://scripts/mobile_performance.gd")
var scripts: Array[GDScript] = []

func android_script(path: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace('OS.has_feature("android")', "true")
	script.take_over_path(path)
	assert(script.reload() == OK)
	scripts.append(script)
	return script

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	android_script("res://scripts/world_visuals.gd")
	var world: Node3D = android_script("res://scripts/world.gd").new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	Mobile.configure_world(world)
	var entries: Array = []
	var roots := 0
	for node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if node.get_meta("mobile_animated_grass_fade", false):
			var entry = Mobile.DistanceEntry.new(node, node.global_position, 0.0, 0.0)
			entries.append(entry)
			roots += entry.grass_root_points.size()
	assert(not entries.is_empty())
	var rectangle_positive := 0
	var root_positive := 0
	var empty_cache_hits := 0
	# Continuous forward/back road movement plus lateral movement.
	for step in range(1201):
		var position := Vector3(2.0 + 12.0 * sin(step * 0.01), 1.6,
			61.0 - 100.0 * sin(step * PI / 1200.0))
		var point := Vector2(position.x, position.z)
		for entry in entries:
			var dx := point.x - clampf(point.x, entry.grass_min_x, entry.grass_max_x)
			var dz := point.y - clampf(point.y, entry.grass_min_z, entry.grass_max_z)
			var rectangle: bool = dx * dx + dz * dz <= entry.grass_fade_squared
			if rectangle:
				rectangle_positive += 1
				if entry.grass_empty_radius_squared > 0.0 and point.distance_squared_to(entry.grass_empty_center) < entry.grass_empty_radius_squared:
					empty_cache_hits += 1
			var expected := false
			for grass_root in entry.grass_root_points:
				if point.distance_squared_to(grass_root) <= entry.grass_fade_squared:
					expected = true
					break
			var actual: bool = entry.grass_in_range(position)
			assert(actual == expected, "World root oracle mismatch at step %d" % step)
			if actual:
				root_positive += 1
	var result := {
		"scope": "OpenGL Android-asset root-culling correctness inventory, not Android FPS or frustum-visible draw savings",
		"positions": 1201, "grass_batches": entries.size(), "grass_roots": roots,
		"rectangle_positive": rectangle_positive, "root_positive": root_positive,
		"avoided_empty_batch_checks": rectangle_positive - root_positive,
		"empty_cache_hits": empty_cache_hits, "oracle_mismatches": 0
	}
	var output := OS.get_environment("GRASS_WORLD_OUTPUT")
	assert(not output.is_empty())
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("ANDROID_GRASS_WORLD_PASS ", JSON.stringify(result))
	quit()
