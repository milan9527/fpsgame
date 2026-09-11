extends RefCounted

const RADIUS := 0.22
var active := false
var vehicle_ref: WeakRef
var orbit_yaw := 0.0
var orbit_pitch := -0.18
var distance := 6.0
var visible_distance := 6.0
var probe := SphereShape3D.new()

func begin(vehicle) -> void:
	if active and vehicle_ref != null and vehicle_ref.get_ref() == vehicle:
		return
	active = true
	vehicle_ref = weakref(vehicle)
	orbit_yaw = 0.0
	orbit_pitch = -0.18
	distance = 6.0
	visible_distance = distance
	probe.radius = RADIUS

func orbit(relative: Vector2, sensitivity: float) -> void:
	if not active or not relative.is_finite() or not is_finite(sensitivity):
		return
	orbit_yaw = wrapf(orbit_yaw - relative.x * sensitivity, -PI, PI)
	orbit_pitch = clampf(orbit_pitch - relative.y * sensitivity, -0.75, 0.30)

func zoom(amount: float) -> void:
	if active and is_finite(amount):
		distance = clampf(distance + amount, 3.0, 8.0)

func update(actor, dt: float) -> void:
	var vehicle = actor.vehicle_ref.get_ref() if actor.is_seated() else null
	if vehicle == null:
		end(actor)
		return
	begin(vehicle)
	var pivot: Vector3 = vehicle.global_position + Vector3.UP * 1.4
	var basis := Basis(Vector3.UP, vehicle.global_rotation.y + orbit_yaw) * Basis(Vector3.RIGHT, orbit_pitch)
	var offset := basis * Vector3(0, 0, distance)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	query.motion = offset
	query.collision_mask = 1 | 2 | 4
	var ignored: Array[RID] = [vehicle.get_rid(), actor.get_rid()]
	for index in range(2):
		var occupant = vehicle.seats.occupant(index)
		if occupant != null and occupant != actor:
			ignored.append(occupant.get_rid())
	query.exclude = ignored
	query.margin = 0.01
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var allowed := distance
	if not space.intersect_shape(query, 1).is_empty():
		allowed = 0.0
	else:
		var fraction := space.cast_motion(query)
		if fraction[0] < 1.0:
			allowed = maxf(0.0, distance * fraction[0] - 0.04)
	# Pull in immediately to avoid clipping, recover gently when obstruction clears.
	visible_distance = minf(allowed, move_toward(visible_distance, allowed, maxf(0, dt) * 5.0))
	var camera: Camera3D = actor.camera
	camera.global_transform = Transform3D(basis, pivot + offset.normalized() * visible_distance)
	camera.fov = 78.0
	actor.body_mesh.visible = not actor.alive or visible_distance > 1.25
	actor.camera_error = Vector3.ZERO

func end(actor) -> void:
	if not active:
		return
	active = false
	vehicle_ref = null
	actor.camera.transform = Transform3D.IDENTITY
	actor.body_mesh.visible = not actor.local_view
	actor.camera_error = Vector3.ZERO
