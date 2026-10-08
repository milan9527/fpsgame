extends SceneTree

class ProbeActor:
	extends Node3D
	var body_shape := CollisionShape3D.new()

	func _init() -> void:
		body_shape.shape = CapsuleShape3D.new()
		body_shape.shape.height = 1.8

	func _exit_tree() -> void:
		body_shape.free()

func _initialize() -> void:
	call_deferred("run")

func box(parent: Node3D, at: Vector3, size: Vector3, mask: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = mask
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	parent.add_child(body)
	body.position = at

func reference(avoidance, actor, start: Vector3, end: Vector3, mask: int) -> bool:
	var query: PhysicsShapeQueryParameters3D = avoidance.query_at(actor, start, end, mask)
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	return space.cast_motion(query)[0] >= 0.999

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor := ProbeActor.new()
	scene.add_child(actor)
	box(scene, Vector3(0, -0.5, 0), Vector3(50, 1, 50), 1)
	box(scene, Vector3(0, 1.5, 0), Vector3(1, 3, 8), 4)
	box(scene, Vector3(7, 1.5, 0), Vector3(1, 3, 8), 1)
	box(scene, Vector3(20, 0.9, -4.5), Vector3(2.25, 1.8, 3.6), 4)
	await physics_frame
	await physics_frame
	var avoidance = load("res://scripts/bot_vehicle_avoidance.gd").new()
	# A position reached by the actual moving capsule beside a vehicle corner
	# must permit escape without permitting travel through the vehicle.
	actor.body_shape.shape.radius = 0.38
	var corner := Vector3(18.517252, 0.000939, -6.483957)
	assert(avoidance.clear_segment(actor, corner, Vector3(18, 0.000939, -7), 4),
		"A valid vehicle-corner position must permit an outgoing route")
	assert(not avoidance.clear_segment(actor, corner, Vector3(20, 0.000939, -4.5), 4),
		"Matching the actor footprint must still reject a route through the hull")
	actor.body_shape.shape.radius = 0.5
	var cases := [
		[Vector3(-4, 0.02, 0), Vector3(4, 0.02, 0), 5, false],
		[Vector3(-4, 0.02, 0), Vector3(4, 0.02, 0), 1, true],
		[Vector3(4, 0.02, 0), Vector3(10, 0.02, 0), 1, false],
		[Vector3(0, 0.02, 0), Vector3(-4, 0.02, 0), 5, false],
		[Vector3(0, 0.02, 0), Vector3(0, 0.02, 0), 5, false],
		[Vector3(-4, 0.02, 6), Vector3(4, 0.02, 6), 5, true],
		[Vector3(-4, 0.02, 6), Vector3(-4, 0.02, 6), 5, true],
	]
	for entry in cases:
		assert(reference(avoidance, actor, entry[0], entry[1], entry[2]) == entry[3])
		assert(avoidance.clear_segment(actor, entry[0], entry[1], entry[2]) == entry[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260929
	var rejected_sweeps := 0
	var old_queries := 0
	var new_queries := 0
	for index in range(2000):
		actor.body_shape.shape.height = 1.1 if index % 2 else 1.8
		var start := Vector3(rng.randf_range(-10, 10), 0.02, rng.randf_range(-7, 7))
		var end := Vector3(rng.randf_range(-10, 10), 0.02, rng.randf_range(-7, 7))
		var mask: int = [1, 4, 5][index % 3]
		assert(avoidance.clear_segment(actor, start, end, mask) == reference(avoidance, actor, start, end, mask),
			"Sweep-first ordering must preserve collision decisions")
		var query: PhysicsShapeQueryParameters3D = avoidance.query_at(actor, start, end, mask)
		var space := actor.get_world_3d().direct_space_state
		var start_clear := space.intersect_shape(query, 1).is_empty()
		var sweep_clear := space.cast_motion(query)[0] >= 0.999
		old_queries += 2 if start_clear else 1
		new_queries += 2 if sweep_clear else 1
		if start_clear and not sweep_clear:
			rejected_sweeps += 1
	assert(rejected_sweeps > 0)
	# Each expansion shares its start but the next expansion can change stance,
	# mask and origin. Compare all outgoing decisions with uncached physics.
	for batch in range(100):
		actor.body_shape.shape.height = 1.1 if batch % 2 else 1.8
		var start := Vector3(rng.randf_range(-10, 10), 0.02, rng.randf_range(-7, 7))
		var mask: int = [1, 4, 5][batch % 3]
		avoidance.graph_start_cache_enabled = true
		avoidance.graph_start_clear = -1
		for edge in range(18):
			var end := Vector3(rng.randf_range(-10, 10), 0.02, rng.randf_range(-7, 7))
			assert(avoidance.clear_segment(actor, start, end, mask) == reference(avoidance, actor, start, end, mask),
				"Shared-start caching must preserve every outgoing collision decision")
		avoidance.graph_start_cache_enabled = false
		avoidance.graph_start_clear = -1
	var nodes: Array[Vector3] = [Vector3(-4, 0.02, 6), Vector3(4, 0.02, 6)]
	var overlapping_nodes: Array[Vector3] = [
		Vector3(0, 0.02, 0), Vector3(-4, 0.02, 0),
		Vector3(-4, 0.02, 6), Vector3(4, 0.02, 6)]
	avoidance.solve_route(actor, overlapping_nodes)
	assert(avoidance.route.is_empty(), "An overlapping start cannot produce a route")
	assert(avoidance.graph_space == null, "An unreachable search must release its physics space")
	assert(not avoidance.graph_start_cache_enabled and avoidance.graph_start_clear == -1,
		"An aborted expansion must clear its collision cache")
	avoidance.solve_route(actor, nodes)
	assert(avoidance.route.size() == 1, "A replan from a clear start must still succeed")
	assert(avoidance.graph_space == null, "A successful search must release its physics space")
	assert(not avoidance.graph_start_cache_enabled and avoidance.graph_start_clear == -1,
		"A completed graph search must not retain collision results")
	print("BOT_VEHICLE_SHARED_START_PASS batches=100 edges=1800")
	print("BOT_VEHICLE_SEGMENT_QUERIES_PASS explicit=9 randomized=2000 clear_start_blocked_edges=", rejected_sweeps,
		" old_queries=", old_queries, " new_queries=", new_queries)
	scene.queue_free()
	await process_frame
	quit()
