extends RefCounted
const LIFETIME := 20.0
const MAX_RADIUS := 6.0

static func radius(age: float) -> float:
	return MAX_RADIUS * clampf(age / 1.5, 0, 1)

static func density(age: float) -> float:
	return clampf((LIFETIME - age) / 4, 0, 1) if age >= 0 else 0.0

static func optical_depth(from: Vector3, to: Vector3, center: Vector3, age: float) -> float:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return 0
	var direction := delta / length
	var offset := from - center
	var b := offset.dot(direction)
	var r := radius(age)
	var discriminant := b * b - offset.length_squared() + r * r
	if discriminant <= 0:
		return 0
	var reach := sqrt(discriminant)
	var entry := maxf(0, -b - reach)
	var thickness := maxf(0, minf(length, -b + reach) - entry)
	var total := 0.0
	for i in range(8):
		var point := from + direction * (entry + thickness * (i + 0.5) / 8)
		total += 1.0 - smoothstep(r * 0.65, r, point.distance_to(center))
	return total / 8 * thickness * density(age)
