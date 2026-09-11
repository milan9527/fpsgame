extends CharacterBody3D

# Authority owns simulation. Input contains controls, never position or velocity.
const FORWARD_SPEED := 22.0
const REVERSE_SPEED := 7.0
const ACCELERATION := 8.0
const BRAKING := 16.0
const ROLLING_DRAG := 2.5
const WHEELBASE := 2.4
const INPUT_TIMEOUT := 0.35
const BODY_SIZE := Vector3(2.25, 1.8, 3.6) # Includes tire sweep at full steering lock.
var driver_id := 0
var speed := 0.0
var steering := 0.0
var throttle := 0.0
var steer_input := 0.0
var handbrake := false
var input_age := INPUT_TIMEOUT
var input_sequence := -1
var distance_travelled := 0.0
var grounded := false
var collision_shape: CollisionShape3D
var visual: Node3D
var wheel_rigs: Array[Dictionary] = []

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 4
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(35)
	floor_constant_speed = true
	collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	collision_shape.shape = box
	collision_shape.position.y = BODY_SIZE.y / 2
	add_child(collision_shape)
	if ResourceLoader.exists("res://assets/buggy.glb"):
		visual = load("res://assets/buggy.glb").instantiate()
		add_child(visual)
		for name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
			var wheel := visual.find_child(name, true, false) as Node3D
			if wheel == null:
				continue
			var turn := Node3D.new()
			visual.add_child(turn)
			turn.global_position = wheel.global_position
			var roll := Node3D.new()
			turn.add_child(roll)
			wheel.reparent(roll, true)
			wheel_rigs.append({"turn": turn, "roll": roll, "front": name.begins_with("Wheel_F")})

func reset_controls() -> void:
	throttle = 0
	steer_input = 0
	handbrake = false
	input_age = INPUT_TIMEOUT

func set_driver(peer: int) -> void:
	if peer == driver_id:
		return
	driver_id = peer
	input_sequence = -1
	reset_controls()

func command(peer: int, sequence: int, forward: float, turn: float, brake: bool) -> bool:
	if driver_id == 0 or peer != driver_id or sequence < 0 or sequence <= input_sequence or sequence > input_sequence + 64:
		return false
	if not is_finite(forward) or not is_finite(turn) or absf(forward) > 1.0 or absf(turn) > 1.0:
		return false
	input_sequence = sequence
	input_age = 0
	throttle = forward
	steer_input = turn
	handbrake = brake
	return true

func can_rotate(target_yaw: float) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(Basis(Vector3.UP, target_yaw), global_position + Vector3.UP * (BODY_SIZE.y / 2 + 0.04))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func simulate(dt: float) -> void:
	if not is_finite(dt) or dt <= 0 or dt > 0.05:
		return
	input_age += dt
	var stale := driver_id == 0 or input_age > INPUT_TIMEOUT
	var pedal := 0.0 if stale else throttle
	var brake := stale or handbrake
	var steering_limit := deg_to_rad(28) * lerpf(1.0, 0.45, clampf(absf(speed) / FORWARD_SPEED, 0, 1))
	steering = move_toward(steering, (0.0 if stale else steer_input) * steering_limit, dt * 2.5)
	if grounded:
		if brake:
			speed = move_toward(speed, 0, BRAKING * dt)
		elif absf(pedal) < 0.01:
			speed = move_toward(speed, 0, ROLLING_DRAG * dt)
		elif speed * pedal < -0.1:
			speed = move_toward(speed, 0, BRAKING * dt)
		else:
			speed = clampf(speed + pedal * ACCELERATION * dt, -REVERSE_SPEED, FORWARD_SPEED)
		var target_yaw := rotation.y - speed / WHEELBASE * tan(steering) * dt
		if absf(target_yaw - rotation.y) > 0.00001 and can_rotate(target_yaw):
			rotation.y = wrapf(target_yaw, -PI, PI)
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	velocity.y -= 24.0 * dt
	var before := global_position
	move_and_slide()
	grounded = is_on_floor()
	# A wall hit must reduce engine speed as well as the resulting displacement.
	speed = Vector3(velocity.x, 0, velocity.z).dot(forward)
	distance_travelled += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var wheel_angle := -(global_position - before).dot(forward) / 0.43
	for wheel in wheel_rigs:
		wheel.turn.rotation.y = -steering if wheel.front else 0.0
		wheel.roll.rotation.x = wrapf(wheel.roll.rotation.x + wheel_angle, -PI, PI)
