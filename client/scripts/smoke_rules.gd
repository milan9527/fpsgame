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
	return optical_depth_ray(from, direction, length, center, age)

# Reuse a normalized sight segment when testing several overlapping clouds.
static func optical_depth_ray(from: Vector3, direction: Vector3, length: float, center: Vector3, age: float) -> float:
	# Inline these small formulas in the per-cloud sight hot path to avoid
	# repeated GDScript calls; keep the public helpers for other callers.
	var cloud_density := clampf((LIFETIME - age) / 4.0, 0.0, 1.0) if age >= 0.0 else 0.0
	if cloud_density <= 0.0:
		return 0
	var offset := from - center
	var b := offset.dot(direction)
	var r := MAX_RADIUS * clampf(age / 1.5, 0.0, 1.0)
	# Reject spheres entirely behind or beyond this sight segment before
	# computing the line intersection. Leave a small margin for normalized
	# Vector3 rounding at the endpoints.
	if -b + r < -0.001 or -b - r > length + 0.001:
		return 0
	var discriminant := b * b - offset.length_squared() + r * r
	if discriminant <= 0:
		return 0
	var reach := sqrt(discriminant)
	var entry := maxf(0, -b - reach)
	var thickness := maxf(0, minf(length, -b + reach) - entry)
	# An infinite line can cross the cloud while the sight segment misses it.
	if thickness <= 0.0:
		return 0
	var total := 0.0
	var inner_radius := r * 0.65
	var inner_squared := inner_radius * inner_radius
	var outer_squared := r * r
	# The eight midpoint samples share the same spacing. Keep independent
	# positions (rather than accumulating a step) to avoid cumulative drift.
	var sample_spacing := thickness * 0.125
	for i in range(8):
		var point := from + direction * (entry + sample_spacing * (i + 0.5))
		var distance_squared := point.distance_squared_to(center)
		# Smoothstep is constant in the core and outside the sphere.
		if distance_squared <= inner_squared:
			# Squared distance along the segment is convex. When both extreme
			# midpoint samples are in the uniform core, all eight contribute one.
			# Use the same world-space formula as the loop to retain its rounding.
			if i == 0:
				var last_point := from + direction * (entry + sample_spacing * 7.5)
				if last_point.distance_squared_to(center) <= inner_squared:
					return thickness * cloud_density
			total += 1.0
		elif distance_squared < outer_squared:
			total += 1.0 - smoothstep(inner_radius, r, sqrt(distance_squared))
	return total / 8 * thickness * cloud_density
