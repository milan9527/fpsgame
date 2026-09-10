extends RefCounted

# Six nested destinations; only the active destination is replicated.
const RADII := [80.0, 55.0, 35.0, 20.0, 10.0, 4.0]
const HOLDS := [35.0, 20.0, 15.0, 15.0, 10.0, 10.0]
const SHRINKS := [30.0, 30.0, 25.0, 25.0, 25.0, 20.0]
var centers: Array[Vector2] = [Vector2.ZERO]

func reset(seed_value: int, accepts_center := Callable()) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	centers = [Vector2.ZERO]
	var previous := 110.0
	for radius in RADII:
		# A previously accepted center is a bounded, nested fallback. The initial
		# road intersection is clear in Ash Valley, including before nav sync.
		var selected: Vector2 = centers.back()
		for attempt in range(48):
			var angle := random.randf() * TAU
			var offset: float = sqrt(random.randf()) * (previous - radius) * 0.85
			var candidate: Vector2 = centers.back() + Vector2(cos(angle), sin(angle)) * offset
			if not accepts_center.is_valid() or accepts_center.call(candidate):
				selected = candidate
				break
		centers.append(selected)
		previous = radius

func sample(seconds: float) -> Dictionary:
	if centers.size() != RADII.size() + 1:
		reset(0)
	var left := maxf(0, seconds)
	var previous := 110.0
	for i in RADII.size():
		var duration: float = HOLDS[i] + SHRINKS[i]
		if left < duration:
			var moving: bool = left >= HOLDS[i]
			var blend := clampf((left - HOLDS[i]) / SHRINKS[i], 0, 1)
			return {"center": centers[i].lerp(centers[i + 1], blend), "radius": lerpf(previous, RADII[i], blend), "next_center": centers[i + 1], "next_radius": RADII[i], "stage": i + 1, "moving": moving, "remaining": duration - left if moving else HOLDS[i] - left}
		left -= duration
		previous = RADII[i]
	return {"center": centers.back(), "radius": 4.0, "next_center": centers.back(), "next_radius": 4.0, "stage": 6, "moving": false, "remaining": 0.0}
