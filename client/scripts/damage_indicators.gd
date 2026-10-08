extends RefCounted
const LIFETIME := 900
const MAX_MARKS := 8
var marks: Array[Dictionary] = []

func clear() -> void:
	marks.clear()

func prune(now: int) -> void:
	# HUD redraws call this even with no damage. Retain the bounded array
	# instead of allocating a filter result and invoking a callable per mark.
	for index in range(marks.size() - 1, -1, -1):
		if marks[index].until <= now:
			marks.remove_at(index)

func record(origin: Vector3, receiver: Vector3, now: int) -> void:
	prune(now)
	var offset := Vector2(origin.x - receiver.x, origin.z - receiver.z)
	if not offset.is_finite() or offset.length_squared() <= 0.25:
		return
	var bearing := atan2(-offset.x, -offset.y)
	for mark in marks:
		if absf(wrapf(mark.bearing - bearing, -PI, PI)) < 0.2:
			mark.bearing = bearing
			mark.until = now + LIFETIME
			return
	if marks.size() >= MAX_MARKS:
		var oldest := 0
		for index in range(1, marks.size()):
			if marks[index].until < marks[oldest].until:
				oldest = index
		marks.remove_at(oldest)
	marks.append({"bearing": bearing, "until": now + LIFETIME})

func resume(paused_at: int, now: int) -> void:
	for mark in marks:
		if mark.until > paused_at:
			mark.until += maxi(0, now - paused_at)

func visible_marks(yaw: float, now: int) -> Array[Dictionary]:
	prune(now)
	var result: Array[Dictionary] = []
	for mark in marks:
		result.append({"angle": -PI / 2 - mark.bearing + yaw, "opacity": clampf(float(mark.until - now) / LIFETIME, 0, 1)})
	return result
