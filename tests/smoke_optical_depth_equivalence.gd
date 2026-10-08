extends SceneTree

const Rules = preload("res://scripts/smoke_rules.gd")

func reference(from: Vector3, to: Vector3, center: Vector3, age: float) -> float:
	var length := from.distance_to(to)
	if length < 0.001 or Rules.density(age) <= 0:
		return 0.0
	var direction := (to - from) / length
	var offset := from - center
	var b := offset.dot(direction)
	var r := Rules.radius(age)
	var discriminant := b * b - offset.length_squared() + r * r
	if discriminant <= 0:
		return 0.0
	var reach := sqrt(discriminant)
	var entry := maxf(0, -b - reach)
	var thickness := maxf(0, minf(length, -b + reach) - entry)
	var total := 0.0
	for i in range(8):
		var point := from + direction * (entry + thickness * (i + 0.5) / 8)
		total += 1.0 - smoothstep(r * 0.65, r, point.distance_to(center))
	return total / 8 * thickness * Rules.density(age)

func _initialize() -> void:
	# Short sight rays inside a cloud, including the core/shell boundary and
	# fade-out, must preserve both optical depth and the AI visibility decision.
	for origin in [Vector3.ZERO, Vector3(1000, 2, -1000)]:
		for age in [0.1, 1.5, 2.0, 16.5, 19.0]:
			var core := Rules.radius(age) * 0.65
			for extent in [0.1, 0.99, 1.0, 1.01, 1.2]:
				var from: Vector3 = origin - Vector3(core * extent, 0, 0)
				var to: Vector3 = origin + Vector3(core * extent, 0, 0)
				var expected := reference(from, to, origin, age)
				var actual := Rules.optical_depth(from, to, origin, age)
				assert(absf(actual - expected) < 0.00001, "Core optical depth drift")
				assert((actual >= 1.5) == (expected >= 1.5), "Core visibility threshold drift")
	# Endpoint tangencies, slight overlaps, and clouds beyond either endpoint.
	# Include large world coordinates to exercise Vector3 rounding.
	for origin in [Vector3.ZERO, Vector3(1000, 2, -1000)]:
		for axial in [-100.0, -6.001, -6.0, -5.999, 0.0, 10.0, 15.999, 16.0, 16.001, 100.0]:
			for lateral in [0.0, 5.999, 6.0, 6.001]:
				var end: Vector3 = origin + Vector3(10, 0, 0)
				var center: Vector3 = origin + Vector3(axial, lateral, 0)
				var expected := reference(origin, end, center, 2)
				var actual := Rules.optical_depth(origin, end, center, 2)
				assert(absf(actual - expected) < 0.00001, "Endpoint optical depth drift")
	var rng := RandomNumberGenerator.new()
	rng.seed = 386
	var max_error := 0.0
	for i in range(20000):
		var center := Vector3(rng.randf_range(-100, 100), 2, rng.randf_range(-100, 100))
		var from := center + Vector3(rng.randf_range(-12, 12), rng.randf_range(-6, 6), rng.randf_range(-12, 12))
		var to := center + Vector3(rng.randf_range(-12, 12), rng.randf_range(-6, 6), rng.randf_range(-12, 12))
		var age := rng.randf_range(-1, 21)
		var expected := reference(from, to, center, age)
		var actual := Rules.optical_depth(from, to, center, age)
		max_error = maxf(max_error, absf(actual - expected))
		assert(absf(actual - expected) < 0.00001, "Optical depth drift")
		assert((actual >= 1.5) == (expected >= 1.5), "Visibility threshold drift")
	# Exercise short core rays at large coordinates, across fade-out
	# and close to the optical-depth threshold used by AI sight.
	for i in range(10000):
		var center := Vector3(1000, 2, -1000)
		var from := center + Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), rng.randf_range(-2, 2))
		var to := from + Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), rng.randf_range(-2, 2))
		var age := rng.randf_range(1.5, 19.99)
		var expected := reference(from, to, center, age)
		var actual := Rules.optical_depth(from, to, center, age)
		max_error = maxf(max_error, absf(actual - expected))
		assert(absf(actual - expected) < 0.00001, "Short core optical depth drift")
		assert((actual >= 1.5) == (expected >= 1.5), "Short core visibility threshold drift")
	print("SMOKE_OPTICAL_DEPTH_EQUIVALENCE_PASS cases=30000 max_error=", max_error)
	quit()
