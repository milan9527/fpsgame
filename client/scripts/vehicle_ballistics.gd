extends RefCounted

# Dedicated query layer; never participates in movement or grenade physics.
# Used by direct shots, rewind cover and weapon clearance queries.
const LAYER := 16
var bodies: Array[StaticBody3D] = []

func build(vehicle) -> void:
	clear()
	if vehicle.visual == null:
		return
	for node in vehicle.visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if shape == null:
			continue
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.name = "BallisticGeometry"
		body.collision_layer = LAYER
		body.collision_mask = 0
		body.set_meta("vehicle_owner", weakref(vehicle))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		# Parenting below each mesh preserves Blender transforms, including
		# front wheel steering and wheel roll rigs, without copying transforms.
		mesh_instance.add_child(body)
		bodies.append(body)

func clear() -> void:
	for body in bodies:
		if is_instance_valid(body):
			body.collision_layer = 0
			body.queue_free()
	bodies.clear()

static func resolve(hit: Dictionary) -> Dictionary:
	if hit.is_empty():
		return hit
	var body = hit.get("collider")
	if body is StaticBody3D and body.has_meta("vehicle_owner"):
		var vehicle = body.get_meta("vehicle_owner").get_ref()
		if vehicle == null:
			return {}
		var result := hit.duplicate()
		result.collider = vehicle
		result.part = str(body.get_parent().name)
		return result
	return hit

static func trace(space: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, length := 180.0) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or not is_finite(length) or length <= 0 or direction.length_squared() < 0.0001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * length, LAYER)
	query.hit_back_faces = true
	query.hit_from_inside = true
	return resolve(space.intersect_ray(query))
