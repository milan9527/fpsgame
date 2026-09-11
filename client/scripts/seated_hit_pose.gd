extends RefCounted

static var poses: Dictionary = {}

static func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

static func prepare() -> void:
	if not poses.is_empty():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/seated_hitboxes.json"))
	assert(data is Dictionary and data.version == 1)
	for clip in data.poses:
		var boxes := []
		for box in data.poses[clip]:
			boxes.append({"bone": box.bone, "headshot": box.headshot,
				"transform": Transform3D(Basis(vector(box.basis[0]), vector(box.basis[1]), vector(box.basis[2])), vector(box.origin)),
				"bounds": AABB(vector(box.min), vector(box.size))})
		poses[clip] = boxes

static func capture(actor) -> Dictionary:
	if not actor.is_seated():
		return {}
	prepare()
	var car = actor.vehicle_ref.get_ref()
	var clip := "SeatedDowned" if actor.downed else ("SeatedDriver" if actor.vehicle_seat == 0 else "SeatedPassenger")
	return {"p": actor.global_position, "basis": car.global_basis,
		"seated": "%d:%d:%d:%s" % [car.get_instance_id(), actor.vehicle_seat, car.seats.epoch, clip],
		"boxes": poses[clip]}

static func box_distance(origin: Vector3, direction: Vector3, bounds: AABB) -> float:
	var near := 0.0
	var far := INF
	for axis in range(3):
		if absf(direction[axis]) < 0.0000001:
			if origin[axis] < bounds.position[axis] or origin[axis] > bounds.end[axis]:
				return INF
			continue
		var a: float = (bounds.position[axis] - origin[axis]) / direction[axis]
		var b: float = (bounds.end[axis] - origin[axis]) / direction[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
		if near > far:
			return INF
	return near

static func trace(pose: Dictionary, origin: Vector3, direction: Vector3, limit := 180.0) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.0001 or not is_finite(limit) or limit <= 0:
		return {}
	direction = direction.normalized()
	var world := Transform3D(pose.basis, pose.p)
	var result := {}
	for box in pose.boxes:
		var inverse: Transform3D = (world * box.transform).affine_inverse()
		var distance := box_distance(inverse * origin, inverse.basis * direction, box.bounds)
		if distance < limit:
			limit = distance
			result = {"distance": distance, "headshot": box.headshot, "bone": box.bone, "position": origin + direction * distance}
	return result
