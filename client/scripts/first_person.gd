extends RefCounted

var model: Node3D
var weapon_model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var arm_bones: Dictionary = {}
var arm_rest: Dictionary = {}
class ArmRest:
	var shoulder: Transform3D
	var forearm: Transform3D
	var hand: Transform3D
	var upper_direction: Vector3
	var lower_direction: Vector3
	var upper_length: float
	var lower_length: float
	var palm_offset: Vector3

	func _init(rig: Skeleton3D, bones: Vector3i) -> void:
		shoulder = rig.get_bone_global_rest(bones.x)
		forearm = rig.get_bone_global_rest(bones.y)
		hand = rig.get_bone_global_rest(bones.z)
		palm_offset = hand.basis.inverse() * Vector3(0, 0, -0.023)
		var upper := forearm.origin - shoulder.origin
		var lower := hand.origin - forearm.origin
		upper_length = upper.length()
		lower_length = lower.length()
		upper_direction = upper.normalized()
		lower_direction = lower.normalized()

var clips: Dictionary = {}
var active_clip := ""
var available := false
var aim_blend := 0.0
var motion_time := 0.0
var magazine: Node3D
var magazine_rest := Vector3.ZERO
var magazine_rest_rotation_inverse := Basis.IDENTITY
var magazine_rest_rotation := Vector3.ZERO:
	set(value):
		magazine_rest_rotation = value
		# Refresh on weapon binding or rest-pose edits, instead of every reload frame.
		magazine_rest_rotation_inverse = Basis.from_euler(value).inverse()
var weapon_kind := 0
var replacement_magazine: Node3D
var held_magazine: Node3D
var sight_dot: MeshInstance3D
var scope_lens: MeshInstance3D
var sight_position := SIGHT
var wall_blend := 0.0
var reload_contact_error := 0.0
var shoulder_reach_correction := {}
const HIP := Vector3(0.26, -0.24, -0.48)
const AIM := Vector3(0, -0.0975, -0.40)
const SIGHT := Vector3(0, 0.0975, 0.01125)
static var scope_surface: QuadMesh
static var scope_coating: ShaderMaterial

static func create_scope_lens() -> MeshInstance3D:
	# Retain the same GPU resources across warmup and weapon switches.
	if scope_surface == null:
		scope_surface = QuadMesh.new()
		scope_surface.size = Vector2.ONE * 0.060
		scope_coating = ShaderMaterial.new()
		scope_coating.shader = preload("res://shaders/scope_lens.gdshader")
	var lens := MeshInstance3D.new()
	lens.name = "ScopeLens"
	lens.mesh = scope_surface
	lens.material_override = scope_coating
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lens

func setup(gun: Node3D, weapon: Node3D, mobile := OS.has_feature("android")) -> void:
	var asset := "res://assets/first_person_mobile.glb" if mobile else "res://assets/first_person.glb"
	if model != null or not ResourceLoader.exists(asset):
		return
	weapon_model = weapon
	model = load(asset).instantiate()
	load("res://scripts/world_visuals.gd").military_materials(model)
	disable_viewmodel_shadows(model)
	gun.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return
	player = players[0]
	skeleton = skeletons[0]
	# The instantiated viewmodel keeps this skeleton for its entire lifetime.
	for side in ["L", "R"]:
		arm_bones[side] = Vector3i(skeleton.find_bone("UpperArm." + side),
			skeleton.find_bone("Forearm." + side), skeleton.find_bone("Hand." + side))
		# Animation and IK modify poses, never this model's rest geometry.
		arm_rest[side] = ArmRest.new(skeleton, arm_bones[side])
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		var short_name: String = name.get_slice("/", name.get_slice_count("/") - 1)
		clips[short_name] = name
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if short_name == "Hold" else Animation.LOOP_NONE
	var reticle := MeshInstance3D.new()
	sight_dot = reticle
	var dot := SphereMesh.new()
	dot.radius = 0.0015
	dot.height = 0.003
	reticle.mesh = dot
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff4035")
	reticle.material_override = material
	reticle.position = SIGHT
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(reticle)
	available = clips.has("Hold") and clips.has("Reload") and clips.has("Throw") and clips.has("Heal")

func bind_weapon(weapon: Node3D, gun: Node3D, kind: int) -> void:
	weapon_model = weapon
	weapon_kind = kind
	disable_viewmodel_shadows(weapon_model)
	magazine = weapon_model.find_child("*Magazine*", true, false)
	if magazine != null:
		magazine_rest = magazine.position
		magazine_rest_rotation = magazine.rotation
		replacement_magazine = magazine.duplicate()
		replacement_magazine.name = "ReloadReplacement"
		magazine.get_parent().add_child(replacement_magazine)
		replacement_magazine.visible = false
	held_magazine = magazine
	var anchor = weapon_model.find_child("SightAnchor", true, false)
	sight_position = gun.to_local(anchor.global_position) if anchor != null else SIGHT
	if is_instance_valid(scope_lens):
		scope_lens.get_parent().remove_child(scope_lens)
		scope_lens.queue_free()
	scope_lens = null
	if kind == 2:
		scope_lens = create_scope_lens()
		gun.add_child(scope_lens)
		scope_lens.position = sight_position + Vector3(0, 0, 0.0008)
	if sight_dot != null:
		sight_dot.position = sight_position
		sight_dot.scale = Vector3.ONE * [0.6, 0.5, 0.18][kind]

func disable_viewmodel_shadows(root: Node) -> void:
	# Camera-relative meshes produce detached dithered shadows on nearby ground.
	# They still receive lighting; world weapons and remote bodies keep casting.
	if root is GeometryInstance3D:
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		disable_viewmodel_shadows(child)

func update(actor, dt: float, ads: bool) -> void:
	if not available or not actor.alive:
		return
	skeleton.clear_bones_global_pose_override()
	var desired := "Hold"
	var progress := 0.0
	if actor.throw_left > 0:
		desired = "Throw"
		progress = clampf(1 - actor.throw_left / 0.7, 0, 1)
	elif actor.reload_left > 0:
		desired = "Reload"
		progress = clampf(1 - actor.reload_left / actor.RELOAD[actor.weapon], 0, 1)
	elif actor.heal_left > 0:
		desired = "Heal"
		progress = clampf(1 - actor.heal_left / 3.5, 0, 1)
	if desired != active_clip:
		active_clip = desired
		player.play(clips[desired], 0.08 if desired == "Hold" else 0.0)
	if desired == "Hold":
		player.advance(dt)
	else:
		player.seek(player.get_animation(clips[desired]).length * progress, true)
	wall_blend = move_toward(wall_blend, 1.0 if actor.weapon_blocked else 0.0, dt * 8)
	aim_blend = move_toward(aim_blend, 1.0 if ads and not actor.weapon_blocked and desired == "Hold" else 0.0, dt * 7)
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	motion_time += dt * (12 if speed < 6 else 17)
	var bob := sin(motion_time) * minf(speed / 9, 1) * 0.014 * (1 - aim_blend)
	var aim_location := Vector3(-sight_position.x, -sight_position.y, AIM.z)
	var location := HIP.lerp(aim_location, aim_blend) + Vector3(0, bob, actor.weapon_kick * 0.025)
	var angles := Vector3(actor.weapon_kick * 0.045, 0, 0)
	if desired == "Reload":
		var tilt := sin(progress * PI)
		# Expose the receiver side while keeping the sleeve ends behind the eye.
		location += Vector3(-0.08, 0.12, -0.06) * tilt
		angles += Vector3(-0.1, 0.35, -0.35) * tilt
	elif desired == "Throw" or desired == "Heal":
		location += Vector3(-0.08, 0.05, 0.03)
	elif speed > 6 and not ads:
		angles.z = 0.18
		location.y -= 0.035
	if desired == "Hold" or desired == "Reload":
		location += Vector3(-0.03, 0.14, 0.28) * wall_blend
		angles += Vector3(-1.35, 0, 0.1) * wall_blend
	commit_gun_pose(actor.gun, location, angles)
	if weapon_model != null:
		var show_weapon := desired != "Throw" and desired != "Heal"
		if weapon_model.visible != show_weapon:
			weapon_model.visible = show_weapon
	if is_instance_valid(scope_lens):
		if scope_lens.visible != weapon_model.visible:
			scope_lens.visible = weapon_model.visible
	# The HUD owns the ballistic reticle; the gun animation must not move it.
	if sight_dot.visible:
		sight_dot.visible = false
	update_magazine(desired, progress)
	if desired == "Hold" or desired == "Reload":
		# Hand targets stay on the weapon; shoulders follow the torso instead of
		# inheriting the full sight/reload rotation of the camera-relative gun.
		# Both arms use the same node transforms; bone overrides do not change
		# these. Recompute once per update so movement and recoil stay current.
		var skeleton_inverse := skeleton.global_transform.affine_inverse()
		var rig_in_gun: Transform3D = actor.gun.global_transform.affine_inverse() * skeleton.global_transform
		var body_transform: Transform3D = actor.gun.get_parent().global_transform
		var neutral_rig := skeleton_inverse * body_transform * Transform3D(Basis.IDENTITY, HIP) * rig_in_gun
		var body_in_skeleton := skeleton_inverse.basis * body_transform.basis
		for side in ["L", "R"]:
			var hand: int = arm_bones[side].z
			var target := skeleton.get_bone_global_pose_no_override(hand)
			if side == "L" and desired == "Reload":
				target = reload_hand_target(progress)
			pose_arm(side, target, neutral_rig, body_in_skeleton)

# Avoid invalidating the weapon's descendants when a pose component is unchanged.
# Compare exactly so even small recoil and aim changes are retained.
func commit_gun_pose(gun: Node3D, location: Vector3, angles: Vector3) -> void:
	if gun.position != location:
		gun.position = location
	if gun.rotation != angles:
		gun.rotation = angles

# Compute the final magazine pose before dirtying the viewmodel hierarchy.
func update_magazine(desired: String, progress: float) -> void:
	if magazine == null:
		return
	# Withdraw straight from the well, lower to the pouch, then bring a
	# separate magazine back up. The exchange occurs below the view edge.
	var magazine_position := magazine_rest
	var replacement_position := magazine_rest
	var magazine_rotation := magazine_rest_rotation
	var replacement_rotation := magazine_rest_rotation
	var magazine_visible := true
	var replacement_visible := false
	held_magazine = magazine
	if desired == "Reload" and progress > 0.2 and progress < 0.86:
		# Each well needs its own clearance: the long shotgun box must
		# leave the receiver before the wrist turns; the short rifle box
		# should not take the same exaggerated detour.
		var clearance: float = [0.17, 0.21, 0.115][weapon_kind]
		var extracted := Vector3(0, -clearance, 0)
		# Work beside the magwell in the lower-left view, not below the
		# camera. Separate withdrawal from the lateral exchange so the
		# magazine clears the receiver before the wrist turns.
		var exchange := Vector3(-0.19, -clearance - 0.015, -0.035)
		var wrist_turn: Vector3 = [Vector3(0.12, 0.0, -0.32),
			Vector3(0.08, 0.0, -0.22), Vector3(0.18, 0.0, -0.42)][weapon_kind]
		# Removal and return use the same visible workspace. The replacement
		# handoff remains a sampled exchange, not a simulated pouch grab.
		if progress < 0.6:
			if progress < 0.34:
				magazine_position += extracted * smoothstep(0.2, 0.34, progress)
			else:
				var travel := smoothstep(0.34, 0.59, progress)
				magazine_position += extracted.lerp(exchange, travel)
				magazine_rotation += wrist_turn * travel
		else:
			magazine_visible = false
			replacement_visible = true
			held_magazine = replacement_magazine
			if progress < 0.78:
				var travel := smoothstep(0.61, 0.78, progress)
				replacement_position += exchange.lerp(extracted, travel)
				replacement_rotation += wrist_turn * (1.0 - travel)
			else:
				replacement_position += extracted * (1.0 - smoothstep(0.78, 0.86, progress))
	if magazine.position != magazine_position:
		magazine.position = magazine_position
	if magazine.rotation != magazine_rotation:
		magazine.rotation = magazine_rotation
	if magazine.visible != magazine_visible:
		magazine.visible = magazine_visible
	if replacement_magazine.position != replacement_position:
		replacement_magazine.position = replacement_position
	if replacement_magazine.rotation != replacement_rotation:
		replacement_magazine.rotation = replacement_rotation
	if replacement_magazine.visible != replacement_visible:
		replacement_magazine.visible = replacement_visible

func reload_hand_target(progress: float) -> Transform3D:
	var hand: int = arm_bones["L"].z
	var animated := skeleton.get_bone_global_pose_no_override(hand)
	if not held_magazine is MeshInstance3D:
		return animated
	var weight := smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.86, 1.0, progress))
	var bounds: AABB = held_magazine.get_aabb()
	# Palm rests against the left wall of each magazine, including weapon scale.
	var contact := bounds.get_center()
	contact.x = bounds.position.x - 0.018
	var target := skeleton.to_local(held_magazine.to_global(contact))
	var geometry: ArmRest = arm_rest["L"]
	var rest := geometry.hand
	# The transverse support fingers already wrap from the left toward +X.
	# Keep that direction when gripping the magazine's left wall.
	var parent_basis: Basis = skeleton.global_basis.inverse() * held_magazine.get_parent().global_basis
	var wrist_delta := Basis.from_euler(held_magazine.rotation) * magazine_rest_rotation_inverse
	var grip_basis: Basis = parent_basis * wrist_delta * parent_basis.inverse() * rest.basis
	var palm_offset := geometry.palm_offset
	var grip := Transform3D(grip_basis, target - grip_basis * palm_offset)
	var posed := animated.interpolate_with(grip, weight)
	reload_contact_error = (posed * palm_offset).distance_to(target)
	return posed

func pose_arm(side: String, posed: Transform3D, neutral_rig: Transform3D, body_in_skeleton: Basis) -> void:
	var bones: Vector3i = arm_bones[side]
	var upper := bones.x
	var forearm := bones.y
	var hand := bones.z
	var geometry: ArmRest = arm_rest[side]
	var shoulder := geometry.shoulder
	var arm := geometry.forearm
	var upper_length := geometry.upper_length
	var lower_length := geometry.lower_length
	shoulder.origin = neutral_rig * shoulder.origin
	var reach_axis := (posed.origin - shoulder.origin).normalized()
	var distance := posed.origin.distance_to(shoulder.origin)
	var reach := clampf(distance, absf(upper_length - lower_length) + 0.001,
		upper_length + lower_length - 0.008)
	# Only protract the shoulder when the fixed anchor cannot reach. Never
	# stretch the sleeve bones or detach the weapon/magazine contact point.
	shoulder_reach_correction[side] = absf(distance - reach)
	shoulder.origin = posed.origin - reach_axis * reach
	var pole := body_in_skeleton * Vector3(-0.65 if side == "L" else 0.65, -1.0, 0.15)
	pole -= reach_axis * pole.dot(reach_axis)
	if pole.length_squared() < 0.0001:
		pole = reach_axis.cross(Vector3.RIGHT)
	pole = pole.normalized()
	var along := (upper_length * upper_length - lower_length * lower_length + reach * reach) / (2.0 * reach)
	var elbow := shoulder.origin + reach_axis * along + pole * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	shoulder.basis = Basis(Quaternion(geometry.upper_direction,
		(elbow - shoulder.origin).normalized())) * shoulder.basis
	arm.origin = elbow
	arm.basis = Basis(Quaternion(geometry.lower_direction, (posed.origin - elbow).normalized())) * arm.basis
	skeleton.set_bone_global_pose_override(upper, shoulder, 1.0, true)
	skeleton.set_bone_global_pose_override(forearm, arm, 1.0, true)
	skeleton.set_bone_global_pose_override(hand, posed, 1.0, true)
