extends CharacterBody3D

const CharacterAnimation = preload("res://scripts/character_animation.gd")
var character_animation := CharacterAnimation.new()
var grounded := false
const PREDICTION_LIMIT := 120
var prediction_history: Array[Dictionary] = []
var pending_correction: Dictionary = {}
var prediction_ack := -1
var prediction_jump_held := false
var camera_error := Vector3.ZERO
var prediction_corrections := 0

var actor_id: int
var display_name: String
var user_id := ""
var is_bot := false
var health := 100.0
var armor := 50.0
var kills := 0
var rank := 0
var weapon := 0
var ammo := 30
var reserve := 120
var medkits := 2
var grenades := 2
var throw_left := 0.0
var alive := true
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO
var sprint := false
var crouch := false
var crouched := false
var aiming := false
var recoil := 0.0
var weapon_kick := 0.0
var body_shape: CollisionShape3D
const STANDING_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const RECOIL := [0.014, 0.05, 0.065]
var shooting := false
var jump_requested := false
var reload_left := 0.0
var heal_left := 0.0
var fire_left := 0.0
var bot_think := 0.0
var target_id := 0
var target_position := Vector3.ZERO
var last_sequence := -1
var command_tokens := 60.0
var last_command_msec := 0
var head: Node3D
var body_mesh: Node3D
var gun: Node3D
var camera: Camera3D
var muzzle: MeshInstance3D
var flash_left := 0.0
var material: StandardMaterial3D
const CAPACITY := [30, 8, 5]
const DAMAGE := [23.0, 12.0, 78.0]
const INTERVAL := [0.12, 0.85, 1.25]
const RELOAD := [2.0, 2.8, 3.0]
const NAMES := ["AR-30 / CARBINE", "SG-8 / BREACHER", "SR-5 / MARKSMAN"]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	body_shape = shape
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	material = StandardMaterial3D.new()
	material.albedo_color = Color("cb7852") if is_bot else Color("65bfb9")
	if ResourceLoader.exists("res://assets/operator.glb"):
		body_mesh = load("res://assets/operator.glb").instantiate()
	else:
		var fallback := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.36
		mesh.height = 1.8
		fallback.mesh = mesh
		fallback.position.y = 0.9
		fallback.material_override = material
		body_mesh = fallback
	add_child(body_mesh)
	character_animation.setup(body_mesh)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 85
	camera.near = 0.06
	head.add_child(camera)
	gun = Node3D.new()
	gun.position = Vector3(0.26, -0.24, -0.48)
	camera.add_child(gun)
	if ResourceLoader.exists("res://assets/carbine.glb"):
		var model = load("res://assets/carbine.glb").instantiate()
		model.scale = Vector3.ONE * 0.75
		gun.add_child(model)
	else:
		add_gun_box(Vector3(0.11, 0.13, 0.42), Vector3.ZERO, Color("293f46"))
		add_gun_box(Vector3(0.05, 0.05, 0.38), Vector3(0, 0.02, -0.32), Color("111d27"))
		add_gun_box(Vector3(0.07, 0.22, 0.10), Vector3(0, -0.14, 0.03), Color("111d27"))
	muzzle = MeshInstance3D.new()
	var flare := CylinderMesh.new()
	flare.top_radius = 0.0
	flare.bottom_radius = 0.035
	flare.height = 0.12
	flare.radial_segments = 6
	muzzle.mesh = flare
	muzzle.rotation.x = -PI / 2
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe7a0")
	muzzle.material_override = glow
	muzzle.position = Vector3(0, 0.012, -0.47)
	muzzle.visible = false
	gun.add_child(muzzle)
	gun.visible = false

func add_gun_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.metallic = 0.5
	m.material_override = mat
	gun.add_child(m)

func set_local() -> void:
	camera.current = true
	body_mesh.visible = false
	gun.visible = true

func simulate(dt: float) -> void:
	command_tokens = minf(60, command_tokens + dt * 40)
	fire_left = maxf(0, fire_left - dt)
	throw_left = maxf(0, throw_left - dt)
	if not alive:
		return
	rotation.y = yaw
	head.rotation.x = pitch
	recoil = move_toward(recoil, 0, dt * 0.075)
	update_stance()
	if reload_left > 0:
		reload_left -= dt
		if reload_left <= 0:
			var count: int = mini(CAPACITY[weapon] - ammo, reserve)
			ammo += count
			reserve -= count
	if heal_left > 0:
		heal_left -= dt
		if heal_left <= 0:
			health = minf(100, health + 65)
			medkits -= 1
	move_step(dt)

# Shared by authority and prediction. Never changes inventory, damage or timers.
func move_step(dt: float) -> void:
	if not alive:
		return
	update_stance()
	var direction := Basis(Vector3.UP, yaw) * Vector3(move_input.x, 0, move_input.y)
	var speed := 2.8 if crouched else (9.0 if sprint and not shooting and not aiming else 5.5)
	if aiming:
		speed = minf(speed, 3.2)
	if heal_left > 0:
		speed = 2.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not grounded:
		velocity.y -= 24 * dt
	elif jump_requested and not crouched:
		velocity.y = 7.5
	jump_requested = false
	move_and_slide()
	grounded = is_on_floor()
	position.x = clampf(position.x, -115, 115)
	position.z = clampf(position.z, -115, 115)
	if position.y < -10:
		position.y = 4

func predict_movement(cmd: Dictionary, dt: float, active: bool) -> void:
	reconcile_movement()
	if not active or not alive:
		prediction_history.clear()
		prediction_jump_held = false
		return
	var movement := cmd.duplicate()
	# Network one-shot actions remain latched until transmission, but local
	# prediction must not repeat the same jump during those frames.
	movement.jump = cmd.jump and not prediction_jump_held
	prediction_jump_held = cmd.jump
	prediction_history.append({"cmd": movement, "dt": dt})
	if prediction_history.size() > PREDICTION_LIMIT:
		prediction_history.pop_front()
	predict_step(movement, dt)

func predict_step(cmd: Dictionary, dt: float) -> void:
	move_input = Vector2(cmd.x, cmd.z).limit_length()
	yaw = cmd.yaw
	crouch = cmd.crouch
	sprint = cmd.sprint
	aiming = cmd.ads
	shooting = cmd.fire
	jump_requested = cmd.jump
	move_step(dt)

func reconcile_movement() -> void:
	if pending_correction.is_empty():
		return
	var state := pending_correction
	pending_correction = {}
	var ack := int(state.ack)
	if ack < prediction_ack:
		return
	prediction_ack = ack
	var before := position
	var view_yaw := yaw
	var missing_history := not prediction_history.is_empty() and ack < int(prediction_history[0].cmd.seq) - 2
	var teleport := position.distance_to(state.p) > 12
	position = state.p
	velocity = state.vel
	grounded = state.ground
	set_stance(state.crouched)
	while not prediction_history.is_empty() and int(prediction_history[0].cmd.seq) <= ack:
		prediction_history.pop_front()
	if not alive or missing_history or teleport:
		prediction_history.clear()
	else:
		for entry in prediction_history:
			predict_step(entry.cmd, entry.dt)
	yaw = view_yaw
	# Smooth only the camera, never the collision body. Large discontinuities
	# and death snap immediately rather than retaining a stale camera offset.
	if teleport or not alive or missing_history:
		camera_error = Vector3.ZERO
	else:
		camera_error = (camera_error + before - position).limit_length(0.5)
	prediction_corrections += 1

func reload_weapon() -> void:
	if alive and throw_left <= 0 and reload_left <= 0 and heal_left <= 0 and ammo < CAPACITY[weapon] and reserve > 0:
		reload_left = RELOAD[weapon]

func heal() -> void:
	if alive and throw_left <= 0 and medkits > 0 and health < 100 and heal_left <= 0 and reload_left <= 0:
		heal_left = 3.5

func switch_weapon(index: int) -> void:
	if not alive or throw_left > 0 or index < 0 or index > 2 or index == weapon or reload_left > 0:
		return
	# Shared ammunition pool; switching never manufactures rounds.
	reserve += ammo
	weapon = index
	ammo = mini(CAPACITY[weapon], reserve)
	reserve -= ammo
	fire_left = 0.5

func apply_damage(amount: float) -> void:
	if not alive:
		return
	heal_left = 0
	var absorbed := minf(armor, amount * 0.6)
	armor -= absorbed
	health = maxf(0, health - (amount - absorbed))
	if health <= 0:
		alive = false
		collision_layer = 0
		collision_mask = 0
		if not character_animation.available:
			body_mesh.rotation.z = PI / 2
			body_mesh.position.y = 0.3
		gun.visible = false

func pack() -> Dictionary:
	return {"id": actor_id, "n": display_name, "b": is_bot, "p": position, "y": yaw, "v": pitch, "h": health, "a": armor, "k": kills, "r": rank, "w": weapon, "m": ammo, "s": reserve, "med": medkits, "live": alive, "reload": reload_left, "heal": heal_left, "crouched": crouched, "ads": aiming, "recoil": recoil, "vel": velocity, "ground": grounded, "frags": grenades, "throw": throw_left, "ack": last_sequence}

func unpack(data: Dictionary, local: bool) -> void:
	target_position = data.p
	if local:
		pending_correction = data.duplicate()
	elif position.distance_to(target_position) > 12:
		position = target_position
	if not local:
		yaw = data.y
		pitch = data.v
	health = data.h
	armor = data.a
	kills = data.k
	rank = data.r
	weapon = data.w
	ammo = data.m
	reserve = data.s
	medkits = data.med
	reload_left = data.reload
	heal_left = data.heal
	set_stance(data.crouched)
	aiming = data.ads
	recoil = data.recoil
	velocity = data.vel
	grounded = data.ground
	grenades = data.frags
	throw_left = data.throw
	if alive and not data.live:
		apply_damage(10000)
	alive = data.live

func render_frame(dt: float, network_client: bool, local: bool, ads: bool) -> void:
	character_animation.update(self, dt)
	if network_client and not local:
		position = position.lerp(target_position, minf(1, dt * 20))
	rotation.y = yaw
	head.rotation.x = pitch
	flash_left = maxf(0, flash_left - dt)
	muzzle.visible = flash_left > 0
	weapon_kick = move_toward(weapon_kick, 0, dt * 8)
	gun.rotation.x = weapon_kick * 0.06
	if local:
		camera.position = Vector3.ZERO
		if network_client:
			camera_error = camera_error.lerp(Vector3.ZERO, minf(1, dt * 18))
			var origin := camera.global_position
			var desired := origin + camera_error
			if camera_error.length_squared() > 0.000001:
				var query := PhysicsRayQueryParameters3D.create(origin, desired, 1)
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					var distance := maxf(0, origin.distance_to(hit.position) - 0.12)
					desired = origin + camera_error.normalized() * distance
			camera.global_position = desired
		camera.rotation.x = clampf(pitch + recoil, -1.5, 1.5) - pitch
		camera.fov = lerpf(camera.fov, 48.0 if ads else 85.0, dt * 12)
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.012 if move_input.length() > 0.1 else 0.0
		gun.position.y = lerpf(gun.position.y, -0.4 if reload_left > 0 or throw_left > 0 else -0.24 + bob, dt * 12)

func eye_height() -> float:
	return 0.98 if crouched else 1.6

func eye_position() -> Vector3:
	return position + Vector3.UP * eye_height()

func aim_position() -> Vector3:
	return position + Vector3.UP * (0.72 if crouched else 1.1)

func headshot_height() -> float:
	return 0.9 if crouched else 1.42

func update_stance() -> void:
	if crouch:
		set_stance(true)
	elif crouched and can_stand():
		set_stance(false)

func can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# A small floor clearance avoids mistaking the supporting floor for a ceiling.
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (STANDING_HEIGHT / 2 + 0.015))
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func set_stance(lowered: bool) -> void:
	crouched = lowered
	var height := CROUCH_HEIGHT if crouched else STANDING_HEIGHT
	body_shape.shape.height = height
	body_shape.position.y = height / 2
	head.position.y = eye_height()
	if not character_animation.available:
		body_mesh.scale.y = height / STANDING_HEIGHT

func shot_spread() -> float:
	var base: float = [0.009, 0.045, 0.002][weapon]
	if aiming:
		base *= 0.4 if weapon != 1 else 0.85
	if crouched:
		base *= 0.65
	base += Vector2(velocity.x, velocity.z).length() * 0.0018
	base += recoil * 0.08
	return base

func add_recoil() -> void:
	recoil = minf(0.18, recoil + RECOIL[weapon] * (0.7 if crouched else 1.0))
