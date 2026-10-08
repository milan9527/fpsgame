extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func original(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D) -> bool:
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = to - from
	return space.cast_motion(query)[0] < 0.999

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(0.2, 2, 2)
	wall.add_child(collision)
	world.add_child(wall)
	# Only the query helper is under test; avoid actor rendering/AI initialization.
	var actor = load("res://scripts/actor.gd").new()
	actor.weapon_probe.radius = 0.055
	actor.weapon_query.shape = actor.weapon_probe
	actor.weapon_query.collision_mask = 1 | 16
	var reference := PhysicsShapeQueryParameters3D.new()
	reference.shape = actor.weapon_probe
	reference.collision_mask = 1 | 16
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var cases := 0
	for layer in [1, 16, 4]:
		wall.collision_layer = layer
		await physics_frame
		await physics_frame
		for x in [-2.0, -0.156, -0.154, 0.0, 0.154, 0.156, 2.0]:
			for y in [0.0, 0.99, 1.06]:
				for dx in [-3.0, -0.01, 0.0, 0.01, 3.0]:
					var start := Vector3(x, y, 0)
					var finish := start + Vector3(dx, 0, 0)
					assert(actor.weapon_segment_blocked(start, finish, space) == original(start, finish, space, reference),
						"Sweep/overlap ordering must preserve masks, boundaries, zero motion and initial overlap")
					cases += 1
	wall.collision_layer = 1
	await physics_frame
	await physics_frame
	assert(actor.weapon_segment_blocked(Vector3.ZERO, Vector3(2, 0, 0), space), "Starting inside cover is blocked")
	assert(actor.weapon_segment_blocked(Vector3(-2, 0, 0), Vector3(2, 0, 0), space), "Crossing cover is blocked")
	assert(not actor.weapon_segment_blocked(Vector3(-2, 3, 0), Vector3(2, 3, 0), space), "Clear path stays clear")
	print("WEAPON_SEGMENT_QUERY_RULES_PASS cases=", cases, " overlap=ok sweep=ok clear=ok masks=ok")
	actor.free()
	world.queue_free()
	await process_frame
	quit()
