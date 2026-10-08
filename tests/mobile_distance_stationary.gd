extends SceneTree
## Scheduling correctness and avoided work, not Android frame-time evidence.
const Profile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	var controller = Profile.new()
	for index in range(4099):
		var node := Node3D.new()
		controller.distance_nodes.append(Profile.DistanceEntry.new(
			node, Vector3(index % 100, 0, index / 100), 0.0, 30.0))
	assert(controller.static_distance_scan_needed(Vector3.ZERO))
	scan_pass(controller, Vector3.ZERO)
	assert(not controller.static_distance_scan_needed(Vector3.ZERO))
	var skipped := 0
	for frame in range(18000):
		if not controller.static_distance_scan_needed(Vector3.ZERO):
			skipped += 1
	assert(skipped == 18000)
	# No movement epsilon: even a small displacement resumes evaluation.
	assert(controller.static_distance_scan_needed(Vector3(0.000001, 0, 0)))
	var moved := Vector3(60, 0, 0)
	controller.update_distance_visibility(moved, Time.get_ticks_usec() - 2000)
	assert(controller.cull_cursor == 16)
	# Return to the old position mid-pass: cached old results are no longer valid.
	while controller.cull_cursor != 0:
		controller.update_distance_visibility(Vector3.ZERO, Time.get_ticks_usec() - 2000)
	assert(controller.static_distance_scan_needed(Vector3.ZERO))
	scan_pass(controller, Vector3.ZERO)
	assert(not controller.static_distance_scan_needed(Vector3.ZERO))
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.length_squared() < 900.0))
	scan_pass(controller, moved)
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.distance_squared_to(moved) < 900.0))
	assert(not controller.static_distance_scan_needed(moved))
	Profile.baseline_running = true
	assert(controller.static_distance_scan_needed(moved))
	scan_pass(controller, moved)
	Profile.baseline_running = false
	assert(controller.static_distance_scan_needed(moved))
	scan_pass(controller, moved)
	var extra := Node3D.new()
	controller.distance_nodes.append(Profile.DistanceEntry.new(extra, moved, 0.0, 30.0))
	assert(controller.static_distance_scan_needed(moved))
	scan_pass(controller, moved)
	assert(extra.visible)
	for entry in controller.distance_nodes:
		entry.node.free()
	controller.free()
	print("DISTANCE_STATIONARY_PASS entries=4099 stationary_frames_skipped=", skipped,
		" mixed_pass_recovery=true tiny_movement=true visibility_restored=true diagnostic_reset=true")
	quit()

func scan_pass(controller: Profile, position: Vector3) -> void:
	controller.update_distance_visibility(position, Time.get_ticks_usec() - 2000)
	while controller.cull_cursor != 0:
		controller.update_distance_visibility(position, Time.get_ticks_usec() - 2000)
