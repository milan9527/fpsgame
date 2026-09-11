extends CharacterBody3D
signal wrecked(attacker_id: int)
signal impact(other: Node, closing_speed: float, driver: int)

# Authority owns simulation. Input contains controls, never position or velocity.
const FORWARD_SPEED := 22.0
const REVERSE_SPEED := 7.0
const ACCELERATION := 8.0
const BRAKING := 16.0
const ROLLING_DRAG := 2.5
const WHEELBASE := 2.4
const INPUT_TIMEOUT := 0.35
const MAX_HEALTH := 600.0
const MAX_FUEL := 100.0
var health := MAX_HEALTH
var fuel := MAX_FUEL
var destroyed := false
var vehicle_id := 0
var collision_time := 0.0
var collision_cooldowns: Dictionary = {}
const BODY_SIZE := Vector3(2.25, 1.8, 3.6) # Includes tire sweep at full steering lock.
const ARENA_LIMIT := 115.0
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
var seats

func _ready() -> void:
	seats = preload("res://scripts/vehicle_seats.gd").new(self)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
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

func command(peer: int, sequence: int, forward: float, turn: float, brake: bool, seat_epoch := -1) -> bool:
	if destroyed:
		return false
	if seats != null and seats.slots[0] != null:
		var driver = seats.occupant(0)
		if driver == null or not driver.alive or driver.downed or seat_epoch != seats.epoch:
			return false
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

func take_damage(amount: float, attacker_id := 0) -> float:
	if destroyed or not is_finite(amount) or amount <= 0:
		return 0.0
	var applied := minf(health, amount)
	health -= applied
	if health <= 0:
		destroyed = true
		set_driver(0)
		update_wreck_visual()
		wrecked.emit(attacker_id)
	return applied

func update_wreck_visual() -> void:
	if not destroyed or visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("292c2b")
	material.roughness = 1.0
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material

func collision_key(other: Node) -> String:
	if other.get_script() == get_script():
		return "v:%d" % other.vehicle_id
	if other is CharacterBody3D and (other.collision_layer & 2) != 0:
		return "a:%d" % other.actor_id
	if other is Node3D:
		return "s:" + var_to_bytes(other.global_transform).hex_encode()
	return "node:%d" % other.get_instance_id()

func can_rotate(target_yaw: float) -> bool:
	var extent := horizontal_extent(target_yaw)
	if absf(global_position.x) + extent.x > ARENA_LIMIT or absf(global_position.z) + extent.y > ARENA_LIMIT:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(Basis(Vector3.UP, target_yaw), global_position + Vector3.UP * (BODY_SIZE.y / 2 + 0.04))
	query.collision_mask = collision_mask
	var excluded: Array[RID] = [get_rid()]
	for index in range(2):
		var occupant = seats.occupant(index)
		if occupant != null:
			excluded.append(occupant.get_rid())
	query.exclude = excluded
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func horizontal_extent(heading: float) -> Vector2:
	return Vector2(absf(cos(heading)) * BODY_SIZE.x / 2 + absf(sin(heading)) * BODY_SIZE.z / 2,
		absf(sin(heading)) * BODY_SIZE.x / 2 + absf(cos(heading)) * BODY_SIZE.z / 2)

func simulate(dt: float, engine_enabled := true) -> void:
	if not is_finite(dt) or dt <= 0 or dt > 0.05:
		return
	seats.refresh()
	collision_time += dt
	for id in collision_cooldowns.keys():
		if collision_cooldowns[id] <= collision_time:
			collision_cooldowns.erase(id)
	input_age += dt
	var stale := not engine_enabled or destroyed or driver_id == 0 or input_age > INPUT_TIMEOUT
	var pedal := 0.0 if stale else throttle
	if engine_enabled and not destroyed and driver_id != 0 and fuel > 0:
		fuel = maxf(0, fuel - dt * (0.1 + 0.3 * absf(pedal)))
	if fuel <= 0:
		pedal = 0.0
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
	# Match the infantry arena limit, accounting for the entire rotated hull.
	# Limit motion before the sweep instead of teleporting a collider afterwards.
	var extent := horizontal_extent(rotation.y)
	velocity.x = clampf(velocity.x, (-ARENA_LIMIT + extent.x - global_position.x) / dt, (ARENA_LIMIT - extent.x - global_position.x) / dt)
	velocity.z = clampf(velocity.z, (-ARENA_LIMIT + extent.y - global_position.z) / dt, (ARENA_LIMIT - extent.y - global_position.z) / dt)
	velocity.y -= 24.0 * dt
	var before := global_position
	var incoming := velocity
	var impact_driver := driver_id
	move_and_slide()
	grounded = is_on_floor()
	# A wall hit must reduce engine speed as well as the resulting displacement.
	speed = Vector3(velocity.x, 0, velocity.z).dot(forward)
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var other := collision.get_collider() as Node
		if other == null or absf(collision.get_normal().y) > 0.7:
			continue
		var closing := maxf(0, -(incoming - collision.get_collider_velocity()).dot(collision.get_normal()))
		if other is CharacterBody3D and (other.collision_layer & 2) != 0:
			# Running into a parked car is not a vehicle run-over.
			closing = maxf(0, -incoming.dot(collision.get_normal()))
		var id := collision_key(other)
		if closing <= 4 or collision_cooldowns.has(id):
			continue
		collision_cooldowns[id] = collision_time + 1.0
		impact.emit(other, closing, impact_driver)
	distance_travelled += Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var wheel_angle := -(global_position - before).dot(forward) / 0.43
	for wheel in wheel_rigs:
		wheel.turn.rotation.y = -steering if wheel.front else 0.0
		wheel.roll.rotation.x = wrapf(wheel.roll.rotation.x + wheel_angle, -PI, PI)
	seats.refresh()

func _exit_tree() -> void:
	if seats != null:
		seats.clear()
