extends Node3D

var active := false
var target_id := 0
var target_name := ""
var team_filter := 0
var orbit_yaw := 0.0
var orbit_pitch := -0.22
var distance := 4.5
var arm: SpringArm3D
var camera: Camera3D

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1 | 4
	arm.margin = 0.15
	var shape := SphereShape3D.new()
	shape.radius = 0.2
	arm.shape = shape
	arm.spring_length = distance
	add_child(arm)
	camera = Camera3D.new()
	camera.near = 0.06
	camera.fov = 75
	arm.add_child(camera)
	camera.current = false

func reset() -> void:
	active = false
	target_id = 0
	target_name = ""
	team_filter = 0
	camera.current = false
	arm.clear_excluded_objects()
	distance = 4.5
	orbit_pitch = -0.22

func candidates(actors: Dictionary) -> Array:
	var ids: Array = []
	for id in actors:
		if actors[id].alive and (team_filter == 0 or actors[id].team_id == team_filter):
			ids.append(id)
	ids.sort()
	return ids

func is_candidate(id: int, actors: Dictionary) -> bool:
	if not actors.has(id):
		return false
	var actor = actors[id]
	return actor.alive and (team_filter == 0 or actor.team_id == team_filter)

func select(id: int, actors: Dictionary) -> void:
	if not is_candidate(id, actors):
		return
	target_id = id
	var target = actors[id]
	target_name = target.display_name
	orbit_yaw = target.yaw
	orbit_pitch = -0.22
	position = target.position + Vector3.UP * target.eye_height()

func cycle(actors: Dictionary, direction: int) -> void:
	if not active:
		return
	var ids := candidates(actors)
	if ids.is_empty():
		target_id = 0
		target_name = ""
		return
	var index := ids.find(target_id)
	select(ids[posmod(index + direction, ids.size())], actors)

func update_view(actors: Dictionary, local_id: int, phase: String) -> void:
	if not actors.has(local_id):
		reset()
		return
	var local = actors[local_id]
	team_filter = local.team_id
	if local.alive or phase not in ["live", "finished"]:
		if active:
			reset()
			local.camera.current = true
		return
	if not active:
		active = true
		position = local.position + Vector3.UP * 1.6
		local.body_mesh.visible = true
	camera.current = true
	if not is_candidate(target_id, actors):
		cycle(actors, 1)
	arm.clear_excluded_objects()
	if target_id != 0:
		var target = actors[target_id]
		position = target.position + Vector3.UP * target.eye_height()
		target_name = target.display_name
		if target.is_seated():
			var vehicle = target.vehicle_ref.get_ref()
			position = vehicle.global_position + Vector3.UP * 1.4
			arm.add_excluded_object(vehicle.get_rid())
	else:
		position = local.position + Vector3.UP * 1.6
	arm.rotation = Vector3(orbit_pitch, orbit_yaw, 0)
	arm.spring_length = distance

func orbit(relative: Vector2, sensitivity: float) -> void:
	orbit_yaw = wrapf(orbit_yaw - relative.x * sensitivity, -PI, PI)
	orbit_pitch = clampf(orbit_pitch - relative.y * sensitivity, -1.0, 0.45)

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, 1.8, 8)
