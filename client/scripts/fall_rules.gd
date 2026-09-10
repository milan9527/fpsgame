extends RefCounted
const SAFE_SPEED := 12.0

static func damage_for_speed(speed: float) -> float:
	if not is_finite(speed) or speed <= SAFE_SPEED:
		return 0.0
	# Energy above the safe landing threshold; independent of frame rate.
	return minf(100.0, (speed * speed - SAFE_SPEED * SAFE_SPEED) * 0.45)
