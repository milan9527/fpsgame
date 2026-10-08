extends RefCounted

const RADIUS := 0.22
var active := false
var vehicle_ref: WeakRef
var orbit_yaw := 0.0
var orbit_pitch := -0.18
var distance := 6.0
var visible_distance := 6.0
var probe := SphereShape3D.new()
var query := PhysicsShapeQueryParameters3D.new()
var excluded_rids: Array[RID] = []

func _init() -> void:
	query.shape = probe
	query.collision_mask = 1 | 2 | 4
	query.margin = 0.01

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
	var probe_transform := Transform3D(Basis.IDENTITY, pivot)
	if query.transform != probe_transform:
		query.transform = probe_transform
	if query.motion != offset:
		query.motion = offset
	# Rebuild exclusions each frame: passengers can enter or leave while the
	# camera keeps the same query resource across frames and vehicle switches.
	var ignored: Array[RID] = [vehicle.get_rid(), actor.get_rid()]
	for index in range(2):
		var occupant = vehicle.seats.occupant(index)
		if occupant != null and occupant != actor:
			ignored.append(occupant.get_rid())
	# The physics setter rebuilds its exclusion set. Keep checking seats each
	# frame, but only rebuild the native set when membership changes.
	if ignored != excluded_rids:
		query.exclude = ignored
		excluded_rids = ignored
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
	var next_transform := Transform3D(basis, pivot + offset.normalized() * visible_distance)
	if camera.global_transform != next_transform:
		camera.global_transform = next_transform
	if camera.fov != 78.0:
		camera.fov = 78.0
	var show_body: bool = not actor.alive or visible_distance > 1.25
	if actor.body_mesh.visible != show_body:
		actor.body_mesh.visible = show_body
	actor.camera_error = Vector3.ZERO

func end(actor) -> void:
	if not active:
		return
	active = false
	vehicle_ref = null
	actor.camera.transform = Transform3D.IDENTITY
	actor.body_mesh.visible = not actor.local_view
	actor.camera_error = Vector3.ZERO
