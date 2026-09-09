extends RefCounted

var model: Node3D
var weapon_model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var clips: Dictionary = {}
var active_clip := ""
var available := false
var aim_blend := 0.0
var motion_time := 0.0
var magazine: Node3D
var magazine_rest := Vector3.ZERO
var sight_dot: MeshInstance3D
var sight_position := SIGHT
var wall_blend := 0.0
const HIP := Vector3(0.26, -0.24, -0.48)
const AIM := Vector3(0, -0.0975, -0.40)
const SIGHT := Vector3(0, 0.0975, 0.01125)

func setup(gun: Node3D, weapon: Node3D) -> void:
	if model != null or not ResourceLoader.exists("res://assets/first_person.glb"):
		return
	weapon_model = weapon
	model = load("res://assets/first_person.glb").instantiate()
	gun.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return
	player = players[0]
	skeleton = skeletons[0]
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
	for stock in weapon_model.find_children("*Butt*", "Node3D", true, false):
		stock.visible = false
	magazine = weapon_model.find_child("*Magazine*", true, false)
	if magazine != null:
		magazine_rest = magazine.position
	var anchor = weapon_model.find_child("SightAnchor", true, false)
	sight_position = gun.to_local(anchor.global_position) if anchor != null else SIGHT
	if sight_dot != null:
		sight_dot.position = sight_position
		sight_dot.scale = Vector3.ONE * [0.6, 0.5, 0.18][kind]

func update(actor, dt: float, ads: bool) -> void:
	if not available or not actor.alive:
		return
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
		location += Vector3(-0.10, 0.16, -0.10) * tilt
		angles += Vector3(-0.1, 0, -0.35) * tilt
	elif desired == "Throw" or desired == "Heal":
		location += Vector3(-0.08, 0.05, 0.03)
	elif speed > 6 and not ads:
		angles.z = 0.18
		location.y -= 0.035
	if desired == "Hold" or desired == "Reload":
		location += Vector3(-0.03, 0.14, 0.28) * wall_blend
		angles += Vector3(-1.35, 0, 0.1) * wall_blend
	actor.gun.position = location
	actor.gun.rotation = angles
	if weapon_model != null:
		weapon_model.visible = desired not in ["Throw", "Heal"]
	sight_dot.visible = desired not in ["Throw", "Heal"] and not actor.weapon_blocked
	if magazine != null:
		magazine.position = magazine_rest + Vector3(0, -0.32 * sin(progress * PI) ** 2 if desired == "Reload" else 0.0, 0)
