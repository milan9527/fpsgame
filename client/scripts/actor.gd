extends CharacterBody3D

const CharacterAnimation = preload("res://scripts/character_animation.gd")
const FirstPerson = preload("res://scripts/first_person.gd")
const AnimationCadence = preload("res://scripts/animation_cadence.gd")
var character_animation := CharacterAnimation.new()
var first_person := FirstPerson.new()
var animation_cadence := AnimationCadence.new()
var mobile_animation := OS.has_feature("android")
var gun_model: Node3D
var third_person_gun: Node3D
var weapon_bone := -1
var weapon_rest_offset := Transform3D.IDENTITY
var third_person_magazine: Node3D
var third_person_magazine_rest := Transform3D.IDENTITY
var visual_weapon := -1
var visual_grip := -1
var grips := 0
var grip_slots := PackedInt32Array([0, 0, 0])
const GRIP_MODEL = preload("res://assets/foregrip.glb")
var local_view := false
const WEAPON_MODELS := ["res://assets/carbine.glb", "res://assets/shotgun.glb", "res://assets/marksman.glb"]
const MOBILE_WEAPON_MODELS := ["res://assets/carbine_mobile.glb", "res://assets/shotgun_mobile.glb", "res://assets/marksman_mobile.glb"]
const AIM_FOV := [48.0, 58.0, 24.0]
const BARREL_ENDS := [Vector3(0, 0.01125, -0.43875), Vector3(0, 0.01875, -0.46875), Vector3(0, 0.01125, -0.66)]
const OPTIC_HEIGHTS := [0.0975, 0.07875, 0.10875]
var weapon_blocked := false
var weapon_probe := SphereShape3D.new()
var weapon_query := PhysicsShapeQueryParameters3D.new()
var grounded := false
const PREDICTION_LIMIT := 120
var prediction_history: Array[Dictionary] = []
var pending_correction: Dictionary = {}
var prediction_ack := -1
var prediction_jump_held := false
var camera_error := Vector3.ZERO
var camera_correction_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 5)
var prediction_corrections := 0

var actor_id: int
var display_name: String
var user_id := ""
var is_bot := false
var health := 100.0
var team_id := 0
var vehicle_ref: WeakRef
var vehicle_exit_guard: WeakRef
var vehicle_seat := -1

var armor := 50.0
var kills := 0
var rank := 0
var weapon := 0
var magazines := PackedInt32Array([30, 8, 5])
var ammo: int:
	get:
		return magazines[weapon]
	set(value):
		magazines[weapon] = value
var reserve := 120
var medkits := 2
var grenades := 2
var smokes := 0
var landing_speed := 0.0
var throw_left := 0.0
var alive := true
var downed := false
var down_health := 0.0
var bleed_left := 0.0
var knock_attacker := 0
var revive_target := 0
var revive_left := 0.0
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO
var sprint := false
var lean_input := 0.0
var lean := 0.0
const LEAN_ANGLE := PI / 10
var crouch := false
var crouched := false
var aiming := false
var recoil := 0.0
var weapon_kick := 0.0
var body_shape: CollisionShape3D
var standing_probe: CapsuleShape3D
var lean_probe: CapsuleShape3D
var standing_query := PhysicsShapeQueryParameters3D.new()
var lean_query := PhysicsShapeQueryParameters3D.new()
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
var navigator
var bot_destination := Vector3.ZERO
var bot_patrol_left := 0.0
var bot_memory_left := 0.0
var bot_last_seen := Vector3.ZERO
var target_position := Vector3.ZERO
var last_sequence := -1
var last_action_sequence := -1
var action_tokens := 10.0
var command_tokens := 60.0
var last_command_msec := 0
var head: Node3D
var body_mesh: Node3D
var gun: Node3D
var camera: Camera3D
var vehicle_camera = preload("res://scripts/vehicle_camera.gd").new()
var muzzle: MeshInstance3D
var flash_left := 0.0
var material: StandardMaterial3D
const CAPACITY := [30, 8, 5]
const DAMAGE := [23.0, 12.0, 78.0]
const INTERVAL := [0.12, 0.85, 1.25]
const RELOAD := [2.0, 2.8, 3.0]
const NAMES := ["AR-30 / CARBINE", "SG-8 / BREACHER", "SR-5 / MARKSMAN"]

func is_seated() -> bool:
	return vehicle_ref != null and vehicle_ref.get_ref() != null

func _ready() -> void:
	weapon_probe.radius = 0.055
	weapon_query.shape = weapon_probe
	weapon_query.collision_mask = 1 | 16 # Terrain and vehicle mesh, never movement hulls.
	collision_layer = 2
	collision_mask = 1 | 2 | 4
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
	var body_asset := "res://assets/operator_mobile.glb" if mobile_animation else "res://assets/operator.glb"
	if ResourceLoader.exists(body_asset):
		body_mesh = load(body_asset).instantiate()
		load("res://scripts/world_visuals.gd").military_materials(body_mesh)
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
	muzzle = preload("res://scripts/muzzle_flash.gd").create()
	gun.add_child(muzzle)
	gun.visible = false
	update_weapon_visuals()

func update_weapon_visuals(force := false) -> void:
	var assembly_changed := visual_weapon != weapon or visual_grip != grip_slots[weapon] or force
	# Entering local view needs a first-person model, but the existing world
	# weapon and its socket binding are already ready for this loadout.
	if not assembly_changed and (not local_view or gun_model != null):
		return
	visual_weapon = weapon
	visual_grip = grip_slots[weapon]
	if assembly_changed and third_person_gun != null:
		third_person_gun.get_parent().remove_child(third_person_gun)
		third_person_gun.queue_free()
	if assembly_changed and character_animation.available:
		third_person_gun = load(MOBILE_WEAPON_MODELS[weapon] if mobile_animation else WEAPON_MODELS[weapon]).instantiate()
		load("res://scripts/world_visuals.gd").weapon_finish(third_person_gun)
		character_animation.skeleton.add_child(third_person_gun)
		# The socket rest is immutable between weapon assemblies. Only its
		# animated pose needs to be fetched on each presentation update.
		weapon_bone = character_animation.skeleton.find_bone("Weapon")
		var rest := character_animation.skeleton.get_bone_global_rest(weapon_bone)
		weapon_rest_offset = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
		third_person_magazine = third_person_gun.find_child("*Magazine*", true, false)
		if third_person_magazine != null:
			third_person_magazine_rest = third_person_magazine.transform
		add_grip_visual(third_person_gun)
		update_weapon_attachment()
	if local_view:
		if gun_model != null:
			gun.remove_child(gun_model)
			gun_model.queue_free()
		gun_model = load(WEAPON_MODELS[weapon]).instantiate()
		load("res://scripts/world_visuals.gd").weapon_finish(gun_model)
		gun_model.scale = Vector3.ONE * 0.75
		gun.add_child(gun_model)
		add_grip_visual(gun_model)
		first_person.bind_weapon(gun_model, gun, weapon)
		var anchor = gun_model.find_child("MuzzleAnchor", true, false)
		if anchor != null:
			muzzle.position = gun.to_local(anchor.global_position)

func add_grip_visual(model: Node3D) -> void:
	if grip_slots[weapon] == 0:
		return
	var attachment = GRIP_MODEL.instantiate()
	attachment.name = "Foregrip"
	attachment.position = Vector3(0, [-0.09, -0.095, -0.067][weapon], -0.23)
	model.add_child(attachment)

func change_grip(index: int, attach: bool) -> bool:
	if not alive or downed or revive_target != 0 or index != weapon or index < 0 or index > 2 or reload_left > 0 or heal_left > 0 or throw_left > 0:
		return false
	if attach:
		if grips <= 0 or grip_slots[index] != 0:
			return false
		grips -= 1
		grip_slots[index] = 1
	else:
		if grips >= 3 or grip_slots[index] == 0:
			return false
		grips += 1
		grip_slots[index] = 0
	return true

func update_weapon_attachment() -> void:
	if third_person_gun == null:
		return
	var show_weapon := not is_seated() and not downed and character_animation.active_clip != "DownedDeath"
	if third_person_gun.visible != show_weapon:
		third_person_gun.visible = show_weapon
	# Hidden by the existing seated/downed presentation rules. Resolve the
	# current socket and magazine again on the first visible update instead
	# of forcing global bone evaluation for a weapon that cannot be drawn.
	if not third_person_gun.visible:
		return
	var skeleton: Skeleton3D = character_animation.skeleton
	# Keep resolving the animated socket, but avoid propagating an unchanged
	# transform through the weapon's mesh/attachment hierarchy.
	var socket_transform := skeleton.get_bone_global_pose(weapon_bone) * weapon_rest_offset
	if third_person_gun.transform != socket_transform:
		third_person_gun.transform = socket_transform
	update_third_person_magazine()

func update_third_person_magazine() -> void:
	if third_person_magazine == null:
		return
	# Compute the final socket pose before notifying the render hierarchy.
	# Starting from rest also restores interrupted reloads and replicated state.
	var next_transform := third_person_magazine_rest
	if reload_left > 0 and character_animation.active_clip.ends_with("Reload"):
		var progress := clampf(1.0 - reload_left / RELOAD[weapon], 0.0, 1.0)
		# Match Hand.L's socket -> belt -> socket keys in build_operator.py.
		# Blender (x, forward, up) is Godot (x, up, -forward).
		var withdrawal := smoothstep(0.18, 0.40, progress) * (1.0 - smoothstep(0.55, 0.73, progress))
		if withdrawal != 0:
			var socket_to_belt := Vector3(-0.305, -0.23, 0.11)
			# Convert model-space motion through the imported node's parent basis.
			var parent := third_person_magazine.get_parent() as Node3D
			next_transform.origin += parent.global_basis.inverse() * third_person_gun.global_basis * socket_to_belt * withdrawal
	if third_person_magazine.transform != next_transform:
		third_person_magazine.transform = next_transform

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
	local_view = true
	camera.current = true
	body_mesh.visible = false
	gun.visible = true
	first_person.setup(gun, gun_model, mobile_animation)
	update_weapon_visuals()

func simulate(dt: float, profile: Callable = Callable()) -> void:
	action_tokens = minf(10, action_tokens + dt * 10)
	command_tokens = minf(60, command_tokens + dt * 40)
	fire_left = maxf(0, fire_left - dt)
	throw_left = maxf(0, throw_left - dt)
	if not alive:
		return
	apply_view_rotation()
	recoil = move_toward(recoil, 0, dt * 0.075)
	var stance_started := Time.get_ticks_usec() if profile.is_valid() else 0
	update_stance()
	if profile.is_valid():
		profile.call("actor_stance", stance_started)
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
	# Authority already refreshed stance before inventory timers, including
	# seated/exit-guard actors. Do not repeat a blocked standing shape query.
	move_step(dt, false, profile)

# Shared by authority and prediction. Never changes inventory, damage or timers.
func move_step(dt: float, refresh_stance: bool = true, profile: Callable = Callable()) -> void:
	landing_speed = 0.0
	if not alive or is_seated():
		return
	if vehicle_exit_guard != null:
		var previous_car = vehicle_exit_guard.get_ref()
		if previous_car != null and previous_car.collision_releases.has(get_instance_id()):
			# The exit pose must remain clear until chassis collision is restored.
			# Keep movement input so a held direction resumes after this boundary.
			velocity = Vector3.ZERO
			jump_requested = false
			return
		vehicle_exit_guard = null
	if downed:
		shooting = false
		aiming = false
		sprint = false
		lean_input = 0
	if refresh_stance:
		update_stance()
	var lean_started := Time.get_ticks_usec() if profile.is_valid() else 0
	update_lean(dt)
	if profile.is_valid():
		profile.call("actor_lean", lean_started)
	# Idle actors need no yaw basis. Keep the original transform for every
	# nonzero input, including analog input below the normal stick deadzone.
	var direction := Vector3.ZERO
	if move_input != Vector2.ZERO:
		direction = Basis(Vector3.UP, yaw) * Vector3(move_input.x, 0, move_input.y)
	var speed := 2.8 if crouched else (9.0 if sprint and not shooting and not aiming else 5.5)
	if absf(lean) > 0.01:
		speed = minf(speed, 2.8)
	if aiming:
		speed = minf(speed, 3.2)
	if heal_left > 0:
		speed = 2.0
	if downed:
		speed = 1.0
		jump_requested = false
	if revive_target != 0:
		speed = 0.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not grounded:
		velocity.y -= 24 * dt
	elif jump_requested and not crouched:
		velocity.y = 7.5
	jump_requested = false
	var was_grounded := grounded
	var impact_velocity := velocity
	var slide_started := Time.get_ticks_usec() if profile.is_valid() else 0
	move_and_slide()
	if profile.is_valid():
		profile.call("actor_slide", slide_started)
	grounded = is_on_floor()
	if grounded and not was_grounded:
		landing_speed = maxf(0.0, -impact_velocity.dot(get_floor_normal()))
	enforce_world_bounds()

func enforce_world_bounds() -> void:
	# Avoid invalidating physics/render transforms after every in-bounds move.
	# Apply all corrections together, including the fall-recovery position.
	var corrected_position := position
	corrected_position.x = clampf(corrected_position.x, -115, 115)
	corrected_position.z = clampf(corrected_position.z, -115, 115)
	if corrected_position.y < -10:
		corrected_position.y = 4
		velocity = Vector3.ZERO
		grounded = false
		landing_speed = 0.0
	if corrected_position != position:
		position = corrected_position

func predict_movement(cmd: Dictionary, dt: float, active: bool) -> void:
	reconcile_movement()
	if not active or not alive or is_seated():
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
	if is_seated():
		return
	move_input = Vector2(cmd.x, cmd.z).limit_length()
	yaw = cmd.yaw
	lean_input = cmd.get("lean", 0.0)
	crouch = cmd.crouch
	sprint = cmd.sprint
	aiming = cmd.ads
	shooting = cmd.fire
	jump_requested = cmd.jump
	move_step(dt)

func reconcile_movement() -> void:
	if is_seated():
		pending_correction.clear()
		prediction_history.clear()
		camera_error = Vector3.ZERO
		return
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
	var teleport := position.distance_squared_to(state.p) > 144.0
	position = state.p
	velocity = state.vel
	grounded = state.ground
	lean = state.get("lean", 0.0)
	set_stance(state.crouched)
	if not alive or missing_history or teleport:
		prediction_history.clear()
	else:
		# A delayed snapshot can acknowledge many inputs at once. Remove the
		# prefix in one copy instead of shifting the remaining queue per input.
		var acknowledged := 0
		while acknowledged < prediction_history.size() and int(prediction_history[acknowledged].cmd.seq) <= ack:
			acknowledged += 1
		if acknowledged == prediction_history.size():
			prediction_history.clear()
		elif acknowledged > 0:
			prediction_history = prediction_history.slice(acknowledged)
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
	if alive and not downed and not is_seated() and revive_target == 0 and throw_left <= 0 and reload_left <= 0 and heal_left <= 0 and ammo < CAPACITY[weapon] and reserve > 0:
		reload_left = RELOAD[weapon]

func heal() -> void:
	if alive and not downed and not is_seated() and revive_target == 0 and throw_left <= 0 and medkits > 0 and health < 100 and heal_left <= 0 and reload_left <= 0:
		heal_left = 3.5

func cancel_heal() -> void:
	# Kits and health change only on completion, so cancellation needs no refund.
	heal_left = 0

func switch_weapon(index: int) -> void:
	if not alive or downed or is_seated() or revive_target != 0 or throw_left > 0 or index < 0 or index > 2 or index == weapon or reload_left > 0:
		return
	# Loaded rounds stay in their own weapon. Only a completed reload transfers
	# reserve ammunition into a magazine.
	weapon = index
	fire_left = 0.5

func total_ammunition() -> int:
	return reserve + magazines[0] + magazines[1] + magazines[2]

func apply_damage(amount: float, ignore_armor := false, can_knock := false) -> void:
	if not alive:
		return
	heal_left = 0
	if downed:
		down_health = maxf(0, down_health - amount)
		if down_health > 0:
			return
	var absorbed := 0.0 if ignore_armor or downed else minf(armor, amount * 0.6)
	armor -= absorbed
	health = maxf(0, health - (amount - absorbed))
	if health <= 0:
		if can_knock and not downed:
			downed = true
			down_health = 100
			bleed_left = 30
			reload_left = 0
			throw_left = 0
			shooting = false
			return
		downed = false
		bleed_left = 0
		alive = false
		collision_layer = 0
		collision_mask = 0
		if not character_animation.available:
			body_mesh.rotation.z = PI / 2
			body_mesh.position.y = 0.3
		gun.visible = false

func pack(include_team := false) -> Dictionary:
	var state := {"id": actor_id, "n": display_name, "b": is_bot, "p": position, "y": yaw, "v": pitch, "h": health, "a": armor, "k": kills, "r": rank, "w": weapon, "m": ammo, "mags": magazines.duplicate(), "s": reserve, "med": medkits, "live": alive, "reload": reload_left, "heal": heal_left, "crouched": crouched, "lean": lean, "ads": aiming, "recoil": recoil, "vel": velocity, "ground": grounded, "frags": grenades, "smokes": smokes, "grips": grips, "grip_slots": grip_slots.duplicate(), "throw": throw_left, "ack": last_sequence}
	if include_team:
		state.team = team_id
		state.downed = downed
		state.down_health = down_health
		state.bleed = bleed_left
		state.revive_target = revive_target
		state.revive_left = revive_left
	return state

func unpack(data: Dictionary, local: bool) -> void:
	target_position = data.p
	if local:
		pending_correction = data.duplicate()
	elif position.distance_squared_to(target_position) > 144.0:
		position = target_position
	if not local:
		yaw = data.y
		pitch = data.v
	downed = data.get("downed", false)
	down_health = data.get("down_health", 0.0)
	bleed_left = data.get("bleed", 0.0)
	revive_target = int(data.get("revive_target", 0))
	revive_left = data.get("revive_left", 0.0)
	health = data.h
	team_id = int(data.get("team", 0))
	armor = data.a
	kills = data.k
	rank = data.r
	weapon = data.w
	magazines = PackedInt32Array(data.mags)
	reserve = data.s
	medkits = data.med
	reload_left = data.reload
	heal_left = data.heal
	if not local:
		lean = data.get("lean", 0.0)
	set_stance(data.crouched)
	aiming = data.ads
	recoil = data.recoil
	velocity = data.vel
	grounded = data.ground
	grenades = data.frags
	smokes = data.get("smokes", 0)
	grips = data.grips
	grip_slots = PackedInt32Array(data.grip_slots)
	throw_left = data.throw
	if alive and not data.live:
		apply_damage(10000)
	alive = data.live

func update_visual_animation(dt: float, local: bool) -> void:
	var step := dt
	if mobile_animation:
		var interval := 0.0
		# Full-rate actors do not need camera/frustum queries. For nearby actors
		# distance alone also guarantees full rate, including behind the camera.
		if not (local or local_view or is_seated()):
			var view := get_viewport().get_camera_3d()
			if view != null:
				var center := global_position + Vector3.UP
				var distance_squared := view.global_position.distance_squared_to(center)
				if distance_squared >= 20.0 * 20.0:
					interval = AnimationCadence.interval_for(
						distance_squared, view.is_position_in_frustum(center), false)
		var state := int(alive) | (int(downed) << 1) | (int(crouched) << 2) \
			| (int(grounded) << 3) | (int(reload_left > 0) << 4) \
			| (int(is_seated()) << 5) | (weapon << 6)
		step = animation_cadence.advance(dt, interval, state)
	if step > 0:
		character_animation.update(self, step)
		update_weapon_attachment()

func apply_view_rotation() -> void:
	# Compare Vector3 values at engine precision, preserving even small turns
	# without dirtying the whole character hierarchy for an unchanged pose.
	var next_rotation := rotation
	next_rotation.y = yaw
	if rotation != next_rotation:
		rotation = next_rotation
	var next_head_rotation := head.rotation
	next_head_rotation.x = pitch
	if head.rotation != next_head_rotation:
		head.rotation = next_head_rotation

func render_frame(dt: float, network_client: bool, local: bool, ads: bool) -> void:
	if local and not is_seated():
		vehicle_camera.end(self)
	update_weapon_visuals()
	var show_gun := local_view and alive and not downed and not is_seated()
	if gun.visible != show_gun:
		gun.visible = show_gun
	update_visual_animation(dt, local)
	if network_client and not local and not is_seated():
		var next_position := position.lerp(target_position, minf(1, dt * 20))
		if position != next_position:
			position = next_position
	apply_view_rotation()
	apply_lean_pose()
	flash_left = maxf(0, flash_left - dt)
	var show_muzzle := flash_left > 0 and not is_seated()
	if muzzle.visible != show_muzzle:
		muzzle.visible = show_muzzle
	weapon_kick = move_toward(weapon_kick, 0, dt * 8)
	var next_gun_rotation := gun.rotation
	next_gun_rotation.x = weapon_kick * 0.06
	if gun.rotation != next_gun_rotation:
		gun.rotation = next_gun_rotation
	if local:
		if is_seated():
			vehicle_camera.update(self, dt)
			return
		if network_client:
			camera_error = camera_error.lerp(Vector3.ZERO, minf(1, dt * 18))
			var next_camera_position := Vector3.ZERO
			# No world transform or collision work is needed without correction.
			# Use exact zero so small reconciliation offsets remain unchanged.
			if camera_error != Vector3.ZERO:
				var origin := head.global_position
				var desired := origin + camera_error
				if camera_error.length_squared() > 0.000001:
					camera_correction_query.from = origin
					camera_correction_query.to = desired
					var hit := get_world_3d().direct_space_state.intersect_ray(camera_correction_query)
					if not hit.is_empty():
						var distance := maxf(0, origin.distance_to(hit.position) - 0.12)
						desired = origin + camera_error.normalized() * distance
				next_camera_position = head.to_local(desired)
			if camera.position != next_camera_position:
				camera.position = next_camera_position
		elif camera.position != Vector3.ZERO:
			camera.position = Vector3.ZERO
		var next_camera_rotation := camera.rotation
		next_camera_rotation.x = clampf(pitch + recoil, -1.5, 1.5) - pitch
		if camera.rotation != next_camera_rotation:
			camera.rotation = next_camera_rotation
		weapon_blocked = weapon_obstructed(ads)
		first_person.update(self, dt, ads)
		var can_aim := ads and not weapon_blocked and reload_left <= 0 and heal_left <= 0 and throw_left <= 0
		update_camera_fov(dt, can_aim)

func update_camera_fov(dt: float, can_aim: bool) -> void:
	var next_fov := lerpf(camera.fov, AIM_FOV[weapon] if can_aim else 85.0, minf(1, dt * 12))
	# Preserve the complete ADS interpolation, including its last small steps.
	# A settled view needs no Camera3D property submission.
	if camera.fov != next_fov:
		camera.fov = next_fov

func eye_height() -> float:
	return 0.98 if crouched else 1.6

func weapon_obstructed(ads: bool) -> bool:
	# Eye and barrel share yaw and roll, but pitch only rotates the barrel.
	var yaw_basis := Basis(Vector3.UP, yaw)
	var facing := yaw_basis * Basis(Vector3.RIGHT, clampf(pitch + recoil, -1.5, 1.5))
	var eye := position + Vector3.UP * eye_height()
	# Upright yaw leaves the vertical eye offset unchanged. Avoid constructing
	# and multiplying an identity roll on the usual unleaned frame.
	if lean != 0.0:
		var roll_basis := Basis(Vector3.BACK, -lean * LEAN_ANGLE)
		facing = facing * roll_basis
		var pivot := Vector3.UP * 0.38
		eye = position + yaw_basis * (pivot + roll_basis * (Vector3.UP * eye_height() - pivot))
	var offset := Vector3(0, -OPTIC_HEIGHTS[weapon], -0.40) if ads else Vector3(0.26, -0.24, -0.48)
	var mount := eye + facing * offset
	var space := get_world_3d().direct_space_state
	if weapon_segment_blocked(eye, mount, space):
		return true
	var tip: Vector3 = mount + facing * BARREL_ENDS[weapon]
	return weapon_segment_blocked(mount, tip, space)

func weapon_segment_blocked(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var query := weapon_query
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = to - from
	# A blocked sweep needs no second query. intersect_shape ignores motion,
	# but remains necessary on clear sweeps: cast_motion ignores initial overlap.
	if space.cast_motion(query)[0] < 0.999:
		return true
	return not space.intersect_shape(query, 1).is_empty()

func eye_position() -> Vector3:
	# Upright offsets are vertical, so yaw cannot change them. These queries
	# also run for remote actors and bot targets, without needing a basis.
	if lean == 0.0:
		return position + Vector3.UP * eye_height()
	return position + Basis(Vector3.UP, yaw) * lean_point(Vector3.UP * eye_height())

func aim_position() -> Vector3:
	if is_seated():
		var pose: Dictionary = preload("res://scripts/seated_hit_pose.gd").capture(self)
		for box in pose.boxes:
			if box.bone == "Hips":
				return pose.p + pose.basis * (box.transform * box.bounds.get_center())
	if lean == 0.0:
		return position + Vector3.UP * (0.72 if crouched else 1.1)
	return position + Basis(Vector3.UP, yaw) * lean_point(Vector3.UP * (0.72 if crouched else 1.1))

func lean_basis() -> Basis:
	var facing := Basis(Vector3.UP, yaw)
	# Upright actors need no roll basis or matrix multiplication.
	if lean == 0.0:
		return facing
	return facing * Basis(Vector3.BACK, -lean * LEAN_ANGLE)

func lean_point(point: Vector3, value := INF) -> Vector3:
	var amount: float = lean if value == INF else value
	var pivot := Vector3.UP * 0.38
	return pivot + Basis(Vector3.BACK, -amount * LEAN_ANGLE) * (point - pivot)

func hit_base() -> Vector3:
	if lean == 0.0:
		return position
	return position + Basis(Vector3.UP, yaw) * lean_point(Vector3.ZERO)

func is_headshot(point: Vector3) -> bool:
	# Yaw preserves height, so upright hit tests need no inverse pose matrix.
	if lean == 0.0:
		return point.y - position.y > headshot_height()
	return (lean_basis().inverse() * (point - hit_base())).y > headshot_height()

func apply_lean_pose() -> void:
	if not alive:
		return
	# Render frames and stance ticks can request the same collision pose.
	# Avoid notifying the physics server unless that pose actually changes.
	var collision_roll := -lean * LEAN_ANGLE
	# Upright actors need no rotation basis or pivot transforms.
	var collision_center: Vector3 = Vector3.UP * body_shape.shape.height / 2
	var visual_base := Vector3.ZERO
	var visual_eye := Vector3.UP * eye_height()
	if lean != 0.0:
		# All three local pose points share the same pivot and roll.
		var pose_basis := Basis(Vector3.BACK, collision_roll)
		var pivot := Vector3.UP * 0.38
		collision_center = pivot + pose_basis * (collision_center - pivot)
		visual_base = pivot + pose_basis * -pivot
		visual_eye = pivot + pose_basis * (visual_eye - pivot)
	var collision_rotation := body_shape.rotation
	var roll_changed := not is_equal_approx(collision_rotation.z, collision_roll)
	if body_shape.position != collision_center or roll_changed:
		# Submit center and roll together so a moving lean only notifies the
		# physics server once. Keep external axes, scale and rotation order.
		var collision_transform := body_shape.transform
		collision_transform.origin = collision_center
		if roll_changed:
			collision_rotation.z = collision_roll
			collision_transform.basis = Basis.from_euler(
				collision_rotation, body_shape.rotation_order) * Basis.from_scale(body_shape.scale)
		body_shape.transform = collision_transform
	# Stable stance ticks also share the visual pose with render updates.
	# Compare live transforms so animation/external changes are still repaired.
	var visual_rotation := body_mesh.rotation
	var visual_roll_changed := not is_equal_approx(visual_rotation.z, collision_roll)
	if body_mesh.position != visual_base or visual_roll_changed:
		# Submit one local transform when both the lean pivot and roll move.
		var visual_transform := body_mesh.transform
		visual_transform.origin = visual_base
		if visual_roll_changed:
			visual_rotation.z = collision_roll
			visual_transform.basis = Basis.from_euler(
				visual_rotation, body_mesh.rotation_order) * Basis.from_scale(body_mesh.scale)
		body_mesh.transform = visual_transform
	if head.position != visual_eye:
		head.position = visual_eye
	if head.rotation.z != 0:
		head.rotation.z = 0
	if not is_equal_approx(camera.rotation.z, collision_roll):
		camera.rotation.z = collision_roll

func update_lean(dt: float) -> void:
	var wanted := 0.0 if sprint or not grounded else clampf(lean_input, -1, 1)
	var candidate := move_toward(lean, wanted, dt * 5)
	if is_equal_approx(candidate, lean):
		apply_lean_pose()
		return
	# Small angular increments prevent a head crossing a thin wall between poses.
	var steps := maxi(1, ceili(absf(candidate - lean) / 0.025))
	var initial := lean
	var query := lean_query
	if lean_probe == null:
		lean_probe = CapsuleShape3D.new()
		lean_probe.radius = 0.37
		query.shape = lean_probe
		query.collision_mask = 7
		query.exclude = [get_rid()]
	var probe_height: float = body_shape.shape.height - 0.02
	if not is_equal_approx(lean_probe.height, probe_height):
		lean_probe.height = probe_height
	var space := get_world_3d().direct_space_state
	# Yaw and capsule height stay fixed throughout this angular sweep.
	# Keep every collision sample, but construct their shared inputs once.
	var yaw_basis := Basis(Vector3.UP, yaw)
	var capsule_center: Vector3 = Vector3.UP * body_shape.shape.height / 2
	var pivot := Vector3.UP * 0.38
	var center_offset := capsule_center - pivot
	var world_pivot := position + yaw_basis * pivot
	for i in range(1, steps + 1):
		var amount := lerpf(initial, candidate, float(i) / steps)
		# The capsule orientation and its pivoted center use the same rotation.
		var roll_basis := Basis(Vector3.BACK, -amount * LEAN_ANGLE)
		var basis := yaw_basis * roll_basis
		var center := world_pivot + basis * center_offset
		query.transform = Transform3D(basis, center)
		if not space.intersect_shape(query, 1).is_empty():
			break
		lean = amount
	apply_lean_pose()

func headshot_height() -> float:
	return 0.9 if crouched else 1.42

func update_stance() -> void:
	if crouch or downed:
		set_stance(true)
	elif crouched and can_stand():
		set_stance(false)

func can_stand() -> bool:
	# These query-only shapes belong to this actor, independently of its
	# changing body capsule. Reuse the physics resource, never collision results.
	if standing_probe == null:
		standing_probe = CapsuleShape3D.new()
		standing_probe.radius = 0.38
		standing_probe.height = STANDING_HEIGHT
		standing_query.shape = standing_probe
		standing_query.collision_mask = 7
		standing_query.exclude = [get_rid()]
	var query := standing_query
	var yaw_basis := Basis(Vector3.UP, yaw)
	# A small floor clearance avoids mistaking the supporting floor for a ceiling.
	if lean == 0.0:
		query.transform = Transform3D(yaw_basis,
			global_position + Vector3.UP * (STANDING_HEIGHT / 2 + 0.015))
	else:
		var roll_basis := Basis(Vector3.BACK, -lean * LEAN_ANGLE)
		var pivot := Vector3.UP * 0.38
		var center := pivot + roll_basis * (Vector3.UP * (STANDING_HEIGHT / 2) - pivot)
		query.transform = Transform3D(yaw_basis * roll_basis,
			global_position + yaw_basis * center + Vector3.UP * 0.015)
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func set_stance(lowered: bool) -> void:
	crouched = lowered
	var height := CROUCH_HEIGHT if crouched else STANDING_HEIGHT
	# Repeated crouch ticks and network snapshots must not invalidate the
	# physics capsule when its dimensions are unchanged. Still refresh lean
	# below: a snapshot can change it independently of stance.
	if not is_equal_approx(body_shape.shape.height, height):
		body_shape.shape.height = height
	# Living actors get their final (possibly leaning) pose below, without
	# first moving the capsule back to an unleaned position.
	if not alive:
		body_shape.position.y = height / 2
		head.position.y = eye_height()
	if not character_animation.available:
		var stance_scale := height / STANDING_HEIGHT
		if body_mesh.scale.y != stance_scale:
			body_mesh.scale.y = stance_scale
	apply_lean_pose()

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
	recoil = minf(0.18, recoil + RECOIL[weapon] * (0.8 if grip_slots[weapon] == 1 else 1.0) * (0.7 if crouched else 1.0))
