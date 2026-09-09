extends RefCounted

# Server-owned history. No client timestamp or client hit result is accepted.
const MAX_REWIND := 0.2
const PRESENTATION_DELAY := 0.05
const MAX_SAMPLES := 32
const RADIUS := 0.38
var samples: Array[Dictionary] = []

static func rewind_age(rtt_ms: float) -> float:
	if not is_finite(rtt_ms) or rtt_ms < 0:
		return 0
	return clampf(rtt_ms / 1000.0 + PRESENTATION_DELAY, 0, MAX_REWIND)

func clear() -> void:
	samples.clear()

func record(time: float, actors: Dictionary) -> void:
	var poses := {}
	for id in actors:
		var actor = actors[id]
		if actor.alive:
			poses[id] = {"p": actor.position, "height": actor.body_shape.shape.height, "head": actor.headshot_height()}
	if not samples.is_empty() and time <= float(samples[-1].time):
		return
	samples.append({"time": time, "poses": poses})
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()

func poses_at(time: float) -> Dictionary:
	if samples.is_empty() or time < float(samples[0].time):
		return {}
	var before: Dictionary = samples[-1]
	var after: Dictionary = samples[-1]
	for i in range(1, samples.size()):
		if float(samples[i].time) > time:
			before = samples[i - 1]
			after = samples[i]
			break
	var weight := 0.0
	if after.time > before.time:
		weight = clampf((time - before.time) / (after.time - before.time), 0, 1)
	var poses := {}
	for id in before.poses:
		if not after.poses.has(id):
			continue
		var a: Dictionary = before.poses[id]
		var b: Dictionary = after.poses[id]
		# Never sweep a teleport into a hittable corridor.
		if a.p.distance_to(b.p) > 3:
			continue
		poses[id] = {"p": a.p.lerp(b.p, weight), "height": a.height, "head": a.head}
	return poses

static func sphere_distance(origin: Vector3, direction: Vector3, center: Vector3) -> float:
	var relative := origin - center
	var b := relative.dot(direction)
	var c := relative.length_squared() - RADIUS * RADIUS
	if c <= 0:
		return 0
	var discriminant := b * b - c
	if discriminant < 0:
		return INF
	var distance := -b - sqrt(discriminant)
	return distance if distance >= 0 else INF

static func capsule_distance(origin: Vector3, direction: Vector3, base: Vector3, height: float) -> float:
	var low := base + Vector3.UP * RADIUS
	var high := base + Vector3.UP * (height - RADIUS)
	var best := minf(sphere_distance(origin, direction, low), sphere_distance(origin, direction, high))
	var relative := origin - base
	var a := direction.x * direction.x + direction.z * direction.z
	var c := relative.x * relative.x + relative.z * relative.z - RADIUS * RADIUS
	if c <= 0 and relative.y >= RADIUS and relative.y <= height - RADIUS:
		return 0
	if a > 0.000001:
		var b := relative.x * direction.x + relative.z * direction.z
		var discriminant := b * b - a * c
		if discriminant >= 0:
			var distance := (-b - sqrt(discriminant)) / a
			var y := relative.y + direction.y * distance
			if distance >= 0 and y >= RADIUS and y <= height - RADIUS:
				best = minf(best, distance)
	return best

func trace(time: float, origin: Vector3, direction: Vector3, limit: float, shooter_id: int, actors: Dictionary) -> Dictionary:
	var hit := {}
	var poses := poses_at(time)
	for id in poses:
		if id == shooter_id or not actors.has(id) or not actors[id].alive:
			continue
		var pose: Dictionary = poses[id]
		var distance := capsule_distance(origin, direction, pose.p, pose.height)
		if distance < limit:
			limit = distance
			var point := origin + direction * distance
			hit = {"collider": actors[id], "position": point, "headshot": point.y - pose.p.y > pose.head}
	return hit
