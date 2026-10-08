extends SceneTree

class TestWorld extends "res://scripts/world.gd":
	func _ready() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func original(world, at: Vector3) -> String:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at - Vector3.UP * 0.8, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider.get_meta("surface", "hard") != "terrain":
		return "step_hard"
	var road := (absf(at.x) <= 8 and absf(at.z) <= 112.5) or (absf(at.z) <= 7 and absf(at.x) <= 112.5)
	return "step_hard" if road else "step_grass"

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	for data in [[Vector3.ZERO, Vector3(240, 0.2, 240), "terrain", 1],
			[Vector3(20, 0.3, 20), Vector3(2, 0.2, 2), "hard", 1],
			[Vector3(25, 0.3, 25), Vector3(2, 0.2, 2), "hard", 2]]:
		var body := StaticBody3D.new()
		body.position = data[0]
		body.collision_layer = data[3]
		body.set_meta("surface", data[2])
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = data[1]
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
	await physics_frame
	await physics_frame
	var query_id: int = world._footstep_query.get_instance_id()
	var checked := 0
	for x in [-120.1, -112.501, -112.5, -8.001, -8.0, 0, 8, 8.001, 20, 25, 112.5, 112.501, 120.1]:
		for z in [-120.1, -112.501, -112.5, -7.001, -7.0, 0, 7, 7.001, 20, 25, 112.5, 112.501, 120.1]:
			for y in [0.2, 0.5, 3.0]:
				var at := Vector3(x, y, z)
				assert(world.footstep_surface(at) == original(world, at), str(at))
				checked += 1
	assert(world.footstep_surface(Vector3(20, 0.5, 20)) == "step_hard")
	assert(world.footstep_surface(Vector3(25, 0.5, 25)) == "step_grass")
	var prior: Vector3 = world._footstep_query.from
	assert(world.footstep_surface(Vector3.ZERO) == "step_hard")
	assert(world._footstep_query.from == prior, "Road must skip physics query")
	assert(world._footstep_query.get_instance_id() == query_id)
	world.queue_free()
	await process_frame
	print("FOOTSTEP_SURFACE_PASS ", checked, " comparisons; road skips query; off-road reuses resource")
	quit()
