extends RefCounted

# Only visual poses are sampled. Physics and network interpolation keep running.
var elapsed := 0.0
var previous_state := -1

static func interval_for(distance_squared: float, on_screen: bool, full_rate: bool) -> float:
	if full_rate or distance_squared < 20.0 * 20.0:
		return 0.0
	if not on_screen:
		return 0.1
	return 1.0 / 30.0 if distance_squared < 50.0 * 50.0 else 1.0 / 15.0

func advance(dt: float, interval: float, state: int) -> float:
	elapsed += dt
	# Death, stance, seating and reload changes must appear immediately.
	if state != previous_state or elapsed + 0.000001 >= interval:
		previous_state = state
		var step := elapsed
		elapsed = 0.0
		return step
	return 0.0
