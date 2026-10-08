extends SceneTree

const Cadence = preload("res://scripts/animation_cadence.gd")

func _initialize() -> void:
	assert(Cadence.interval_for(10000, false, true) == 0.0)
	assert(Cadence.interval_for(100, false, false) == 0.0)
	assert(is_equal_approx(Cadence.interval_for(900, true, false), 1.0 / 30.0))
	assert(is_equal_approx(Cadence.interval_for(10000, true, false), 1.0 / 15.0))
	assert(is_equal_approx(Cadence.interval_for(900, false, false), 0.1))
	var cadence = Cadence.new()
	var simulated := 0.0
	var updates := 0
	for frame in 121:
		var step: float = cadence.advance(1.0 / 60.0, 0.1, 0)
		simulated += step
		if step > 0:
			updates += 1
	assert(updates == 21)
	assert(is_equal_approx(simulated, 121.0 / 60.0))
	# A state transition forces a pose even between scheduled samples.
	assert(cadence.advance(0.01, 0.1, 0) == 0.0)
	assert(is_equal_approx(cadence.advance(0.01, 0.1, 1), 0.02))
	# Returning to the local/near view consumes pending time immediately.
	assert(cadence.advance(0.01, 0.1, 1) == 0.0)
	assert(is_equal_approx(cadence.advance(0.01, 0.0, 1), 0.02))
	print("PASS animation cadence: pose timing, immediate state changes, full-rate return")
	quit()
