extends SceneTree
## Run with OpenGL: frame_post_draw is required, not a headless timing test.
const Profile = preload("res://scripts/mobile_performance.gd")
var controller: Node
var camera: Camera3D
var observed: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func inspect_draw() -> void:
	var position := camera.global_position
	if position not in [Vector3(0, 2.6, 90), Vector3(2, 1.6, 61),
			Vector3(14, 1.65, 49)]:
		return
	if controller.cull_cursor != 0:
		return
	assert(camera.fov == 85.0)
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.distance_squared_to(position) < 100.0))
	var heading := roundi(camera.rotation.y * 8.0 / TAU)
	if not observed.has(position):
		observed[position] = {}
	observed[position][heading] = observed[position].get(heading, 0) + 1

func run() -> void:
	controller = Profile.new()
	camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 60, 80)
	camera.current = true
	var original := camera.transform
	var original_fov := camera.fov
	# Large enough to exercise sliced scans, with disjoint near-object sets.
	for index in range(12000):
		var node := Node3D.new()
		controller.distance_nodes.append(Profile.DistanceEntry.new(
			node, Vector3(index % 100, 0, index / 100), 0.0, 10.0))
	RenderingServer.frame_post_draw.connect(inspect_draw)
	await Profile.warm_world(camera, controller)
	RenderingServer.frame_post_draw.disconnect(inspect_draw)
	assert(observed.size() == 3)
	for position in observed:
		assert(observed[position].size() == 8)
		for heading in observed[position]:
			assert(observed[position][heading] >= 2)
	assert(camera.transform == original)
	assert(camera.fov == original_fov)
	assert(not controller.static_distance_scan_needed(camera.global_position))
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.distance_squared_to(camera.global_position) < 100.0))
		entry.node.free()
	controller.free()
	camera.queue_free()
	print("WORLD_WARMUP_PASS three_positions=true headings=24 min_draws_per_heading=2 entries=12000 camera_and_visibility_restored=true")
	quit()
