extends RigidBody3D

var grenade_id := 0
var owner_id := 0
var kind := 0
var authoritative := true
var fuse := 2.6
var target_position := Vector3.ZERO
const RADIUS := 9.0
const MAX_DAMAGE := 180.0

func _ready() -> void:
	mass = 0.4
	collision_layer = 8 if authoritative else 0
	collision_mask = 1 | 4 if authoritative else 0
	freeze = not authoritative
	continuous_cd = true
	linear_damp = 0.35
	angular_damp = 0.4
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = 0.48
	physics_material.friction = 0.7
	physics_material_override = physics_material
	var collider := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	collider.shape = sphere
	add_child(collider)
	var model_path := "res://assets/smoke_grenade.glb" if kind == 1 else "res://assets/grenade.glb"
	if ResourceLoader.exists(model_path):
		add_child(load(model_path).instantiate())
		return
	var mesh := MeshInstance3D.new()
	var model := SphereMesh.new()
	model.radius = 0.12
	model.height = 0.24
	model.radial_segments = 12
	model.rings = 6
	mesh.mesh = model
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c2d6c9") if kind == 1 else Color("c0a260")
	mesh.material_override = material
	add_child(mesh)
	var cap := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.06, 0.1)
	cap.mesh = box
	cap.position.y = 0.14
	add_child(cap)

func pack() -> Dictionary:
	return {"id": grenade_id, "p": position, "f": fuse, "owner": owner_id, "kind": kind}

func _process(dt: float) -> void:
	if not authoritative:
		position = position.lerp(target_position, minf(1, dt * 22))
