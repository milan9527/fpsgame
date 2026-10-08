extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func distances(point: Vector2, obstacles: Array) -> Vector2:
	var distance := 10.0
	for obstacle: Rect2 in obstacles:
		if obstacle.grow(0.5).has_point(point):
			return Vector2(1, 0)
		var outside := (point - obstacle.get_center()).abs() - obstacle.size * 0.5
		distance = minf(distance, Vector2(maxf(outside.x, 0), maxf(outside.y, 0)).length())
	return Vector2(0, distance)

func _initialize() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 522
	var obstacles: Array = [Rect2(-12, -12, 24, 24), Rect2(0, 0, 0, 0)]
	for index in range(120):
		obstacles.append(Rect2(random.randf_range(-110, 110), random.randf_range(-110, 110),
			random.randf_range(0.1, 20), random.randf_range(0.1, 20)))
	var cells := Visuals.grass_exclusion_cells(obstacles)
	var points: Array[Vector2] = []
	for obstacle: Rect2 in obstacles:
		for margin in [0.4999, 0.5, 0.5001, 9.9999, 10.0, 10.0001]:
			var bounds := obstacle.grow(margin)
			points.append_array([bounds.position, bounds.end,
				Vector2(bounds.position.x, obstacle.get_center().y),
				Vector2(bounds.end.x, obstacle.get_center().y)])
	for index in range(20000):
		points.append(Vector2(random.randf_range(-140, 140), random.randf_range(-140, 140)))
	var candidate_count := 0
	for point in points:
		var nearby: Array = cells.get(Vector2i(floori(point.x / 12.0), floori(point.y / 12.0)), [])
		candidate_count += nearby.size()
		var expected := distances(point, obstacles)
		var actual := distances(point, nearby)
		if expected != actual:
			printerr("GRASS_EXCLUSION_GRID_FAIL ", point, " expected=", expected, " actual=", actual)
			quit(1)
			return
	print("GRASS_EXCLUSION_GRID_PASS points=", points.size(),
		" exact blocked/distance match; candidates=", candidate_count,
		" full_scan_candidates=", points.size() * obstacles.size())
	quit(0)
