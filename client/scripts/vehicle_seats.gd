extends RefCounted

const ANCHORS := [Vector3(-0.43, 0, 0.1), Vector3(0.43, 0, 0.1)]
const DOORS := [Vector3(-1.65, 0.9, 0.1), Vector3(1.65, 0.9, 0.1)]
const EXIT_POINTS := [Vector3(-1.7, 0, 0.1), Vector3(1.7, 0, 0.1), Vector3(-0.8, 0, 2.4), Vector3(0.8, 0, 2.4)]
var vehicle
var slots: Array = [null, null]
var epoch := 0
var entry_query := PhysicsRayQueryParameters3D.new()
var exit_capsule := CapsuleShape3D.new()
var exit_ground_query := PhysicsRayQueryParameters3D.new()
var exit_clearance_query := PhysicsShapeQueryParameters3D.new()

func _init(body) -> void:
	vehicle = body
	entry_query.collision_mask = 7
	entry_query.hit_from_inside = true
	exit_capsule.radius = 0.38
	exit_capsule.height = 1.8
	exit_ground_query.collision_mask = 5
	exit_clearance_query.shape = exit_capsule
	exit_clearance_query.collision_mask = 7
	exit_clearance_query.margin = 0.01

func occupant(index: int):
	if index < 0 or index >= slots.size() or slots[index] == null:
		return null
	return slots[index].actor.get_ref()

func can_enter(actor, index: int, checked_door: Variant = null) -> bool:
	if vehicle.destroyed:
		return false
	if index < 0 or index >= slots.size() or slots[index] != null:
		return false
	if not actor.alive or actor.downed or actor.is_seated() or actor.revive_target != 0:
		return false
	if not vehicle.grounded or absf(vehicle.speed) > 2.0:
		return false
	# Fleet searches already transformed this door in the same synchronous
	# call. Reuse it without caching across vehicle movement or physics ticks.
	var door: Vector3 = vehicle.to_global(DOORS[index]) if checked_door == null else checked_door
	if actor.global_position.distance_to(door) > 2.8:
		return false
	# HUD and interaction checks are synchronous. Refresh the actor exclusion
	# as well as endpoints so a different passenger never inherits stale input.
	entry_query.from = actor.eye_position()
	entry_query.to = door
	entry_query.exclude = [actor.get_rid(), vehicle.get_rid()]
	if not vehicle.get_world_3d().direct_space_state.intersect_ray(entry_query).is_empty():
		return false
	return true

func enter(actor, index: int) -> bool:
	if not can_enter(actor, index):
		return false
	slots[index] = {"actor": weakref(actor), "mask": actor.collision_mask, "layer": actor.collision_layer}
	actor.vehicle_ref = weakref(vehicle)
	actor.vehicle_seat = index
	actor.collision_mask = 0
	vehicle.add_collision_exception_with(actor)
	actor.move_input = Vector2.ZERO
	actor.velocity = Vector3.ZERO
	actor.jump_requested = false
	actor.shooting = false
	actor.aiming = false
	actor.sprint = false
	actor.lean_input = 0
	actor.lean = 0
	actor.crouch = false
	actor.reload_left = 0
	actor.cancel_heal()
	actor.prediction_history.clear()
	actor.pending_correction.clear()
	epoch += 1
	if index == 0:
		vehicle.set_driver(actor.actor_id)
	sync_actor(actor, index)
	return true

func sync_actor(actor, index: int) -> void:
	var seat_position: Vector3 = vehicle.to_global(ANCHORS[index])
	# Refresh also runs for stationary occupied cars. Exact comparisons avoid
	# dirtying the rider's physics/render hierarchy without suppressing motion.
	if actor.global_position != seat_position:
		actor.global_position = seat_position
	actor.yaw = vehicle.global_rotation.y
	if actor.rotation.y != actor.yaw:
		actor.rotation.y = actor.yaw
	actor.velocity = Vector3.ZERO

func find_exit(actor):
	if not vehicle.grounded or absf(vehicle.speed) > 2.0:
		return null
	var space = vehicle.get_world_3d().direct_space_state
	# All candidate queries complete synchronously. Snapshot transforms and
	# exclusions once per search, never across HUD updates or physics frames.
	var vehicle_transform: Transform3D = vehicle.global_transform
	var actor_position: Vector3 = actor.global_position
	var vehicle_rid: RID = vehicle.get_rid()
	var actor_rid: RID = actor.get_rid()
	var actor_exclusion: Array[RID] = [actor_rid]
	var ignored: Array[RID] = [vehicle_rid, actor_rid]
	for index in range(slots.size()):
		var other = occupant(index)
		if other != null and other != actor:
			ignored.append(other.get_rid())
	# The standing shape is immutable; reuse its physics resource for the
	# seated HUD's repeated exit checks while still querying current obstacles.
	var order := [0, 1, 2, 3] if actor.vehicle_seat == 0 else [1, 0, 3, 2]
	exit_ground_query.exclude = [vehicle_rid]
	for index in order:
		var point: Vector3 = vehicle_transform * EXIT_POINTS[index]
		if absf(point.x) > 114.5 or absf(point.z) > 114.5:
			continue
		exit_ground_query.from = point + Vector3.UP * 0.75
		exit_ground_query.to = point - Vector3.UP
		var ground: Dictionary = space.intersect_ray(exit_ground_query)
		if ground.is_empty() or ground.normal.dot(Vector3.UP) < cos(deg_to_rad(35)):
			continue
		point = ground.position + Vector3.UP * 0.04
		if absf(point.y - vehicle_transform.origin.y) > 0.65:
			continue
		# Queries are synchronous; reuse parameters for the seated HUD, but
		# reset cast motion for every candidate and refresh actor exclusions.
		var query := exit_clearance_query
		query.motion = Vector3.ZERO
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.9)
		query.exclude = actor_exclusion
		if not space.intersect_shape(query, 1).is_empty():
			continue
		query.exclude = ignored
		query.transform.origin = actor_position + Vector3.UP * 0.94
		query.motion = point - actor_position - Vector3.UP * 0.04
		if space.cast_motion(query)[0] < 0.999:
			continue
		return point
	return null

func release(actor, point: Vector3) -> void:
	var index: int = actor.vehicle_seat
	if index < 0 or index >= slots.size() or occupant(index) != actor:
		return
	var saved: Dictionary = slots[index]
	slots[index] = null
	actor.vehicle_ref = null
	actor.vehicle_seat = -1
	vehicle.defer_rider_collision(actor)
	actor.collision_mask = saved.mask if actor.alive else 0
	actor.collision_layer = saved.layer if actor.alive else 0
	if actor.is_inside_tree():
		actor.global_position = point
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	actor.prediction_history.clear()
	actor.pending_correction.clear()
	epoch += 1
	if index == 0:
		vehicle.set_driver(0)

func exit(actor) -> bool:
	if not actor.is_seated() or actor.vehicle_ref.get_ref() != vehicle:
		return false
	var point = find_exit(actor)
	if point == null:
		return false
	release(actor, point)
	return true

func refresh() -> void:
	for index in range(slots.size()):
		if slots[index] == null:
			continue
		var actor = occupant(index)
		if actor == null:
			slots[index] = null
			epoch += 1
			if index == 0:
				vehicle.set_driver(0)
			continue
		sync_actor(actor, index)
		if index == 0:
			var desired_driver: int = actor.actor_id if actor.alive and not actor.downed and not vehicle.destroyed else 0
			if vehicle.driver_id != desired_driver:
				vehicle.set_driver(desired_driver)
				epoch += 1
		if not actor.alive or actor.downed or vehicle.destroyed:
			exit(actor) # Stay secured and brake if there is no safe exit yet.

func clear() -> void:
	for index in range(slots.size()):
		var actor = occupant(index)
		if actor != null:
			release(actor, vehicle.to_global(ANCHORS[index]))
		else:
			slots[index] = null
	vehicle.set_driver(0)
