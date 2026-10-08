extends SceneTree

func _initialize() -> void:
	var avoidance = load("res://scripts/bot_vehicle_avoidance.gd").new()
	var body := CollisionShape3D.new()
	body.shape = CapsuleShape3D.new()
	body.shape.height = 1.8
	var actor := {"body_shape": body}
	var first: PhysicsShapeQueryParameters3D = avoidance.query_at(actor, Vector3(1, 2, 3), Vector3(5, 2, 3), 4)
	var identity := first.get_instance_id()
	# Reproduce the mutation made after a blocker sweep, then switch stance,
	# location, and collision mask as the next route-graph edge does.
	first.transform.origin += Vector3(100, 20, -30)
	first.motion = Vector3.ZERO
	body.shape.height = 1.0
	var next: PhysicsShapeQueryParameters3D = avoidance.query_at(actor, Vector3(2, 0, 5), Vector3(-2, 0, 5), 1)
	assert(next.get_instance_id() == identity)
	assert(next.transform.origin.is_equal_approx(Vector3(2, 0.52, 5)))
	assert(next.motion == Vector3(-4, 0, 0))
	assert(next.collision_mask == 1 and is_equal_approx(next.shape.height, 0.96))
	assert(is_equal_approx(next.margin, 0.01))
	var other = load("res://scripts/bot_vehicle_avoidance.gd").new()
	assert(other.shape_query != next and other.capsule != next.shape)
	body.free()
	print("BOT_VEHICLE_QUERY_REUSE_PASS stance=ok sweep_reset=ok mask=ok actor_isolation=ok")
	quit()
