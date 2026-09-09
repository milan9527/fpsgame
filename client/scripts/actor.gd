extends CharacterBody3D

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
var alive := true
var yaw := 0.0
var pitch := 0.0
var move_input := Vector2.ZERO
var sprint := false
var crouch := false
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
	var sphere := SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.13
	muzzle.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffe7a0")
	muzzle.material_override = glow
	muzzle.position = Vector3(0, 0.02, -0.56)
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
	if not alive:
		return
	rotation.y = yaw
	head.rotation.x = pitch
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
	var direction := Basis(Vector3.UP, yaw) * Vector3(move_input.x, 0, move_input.y)
	var speed := 3.0 if crouch else (9.0 if sprint and not shooting else 5.5)
	if heal_left > 0:
		speed = 2.0
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 24 * dt
	elif jump_requested:
		velocity.y = 7.5
	jump_requested = false
	move_and_slide()
	position.x = clampf(position.x, -115, 115)
	position.z = clampf(position.z, -115, 115)
	if position.y < -10:
		position.y = 4

func reload_weapon() -> void:
	if alive and reload_left <= 0 and heal_left <= 0 and ammo < CAPACITY[weapon] and reserve > 0:
		reload_left = RELOAD[weapon]

func heal() -> void:
	if alive and medkits > 0 and health < 100 and heal_left <= 0 and reload_left <= 0:
		heal_left = 3.5

func switch_weapon(index: int) -> void:
	if not alive or index < 0 or index > 2 or index == weapon or reload_left > 0:
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
		body_mesh.rotation.z = PI / 2
		body_mesh.position.y = 0.3
		gun.visible = false

func pack() -> Dictionary:
	return {"id": actor_id, "n": display_name, "b": is_bot, "p": position, "y": yaw, "v": pitch, "h": health, "a": armor, "k": kills, "r": rank, "w": weapon, "m": ammo, "s": reserve, "med": medkits, "live": alive, "reload": reload_left, "heal": heal_left}

func unpack(data: Dictionary, local: bool) -> void:
	target_position = data.p
	if position.distance_to(target_position) > 12:
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
	if alive and not data.live:
		apply_damage(10000)
	alive = data.live

func render_frame(dt: float, network_client: bool, local: bool, ads: bool) -> void:
	if network_client:
		position = position.lerp(target_position, minf(1, dt * 20))
	rotation.y = yaw
	head.rotation.x = pitch
	flash_left = maxf(0, flash_left - dt)
	muzzle.visible = flash_left > 0
	if local:
		camera.fov = lerpf(camera.fov, 48.0 if ads else 85.0, dt * 12)
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.012 if move_input.length() > 0.1 else 0.0
		gun.position.y = lerpf(gun.position.y, -0.4 if reload_left > 0 else -0.24 + bob, dt * 12)
