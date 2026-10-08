extends SceneTree
## CPU microbenchmark only: these are not presented frame times or Android FPS.
const Profile = preload("res://scripts/mobile_performance.gd")

class BenchmarkProfile extends Profile:
	func reference_scan(position: Vector3, started: int) -> void:
		while cull_cursor < distance_nodes.size():
			var entry: Profile.DistanceEntry = distance_nodes[cull_cursor]
			var squared := position.distance_squared_to(entry.center)
			var shown := squared >= entry.begin_squared and squared < entry.end_squared
			if entry.node.visible != shown:
				entry.node.visible = shown
			cull_cursor += 1
			if Time.get_ticks_usec() - started >= 1000:
				break
		if cull_cursor >= distance_nodes.size():
			cull_cursor = 0
			cull_seconds = 0.05

func _initialize() -> void:
	var controller = BenchmarkProfile.new()
	for index in range(4099):
		var node := Node3D.new()
		controller.distance_nodes.append(Profile.DistanceEntry.new(
			node, Vector3(index % 100, 0, index / 100), 0.0, 30.0))
	# An expired budget must yield after one batch, retain its cursor,
	# and eventually visit the final partial batch.
	controller.update_distance_visibility(Vector3.ZERO, Time.get_ticks_usec() - 2000)
	assert(controller.cull_cursor == 16)
	var calls := 1
	while controller.cull_cursor != 0:
		controller.update_distance_visibility(Vector3.ZERO, Time.get_ticks_usec() - 2000)
		calls += 1
	assert(calls == 257)
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.length_squared() < 900.0))
	var samples := {"per_entry_clock_us": [], "batch16_clock_us": []}
	for iteration in range(220):
		# Alternate order, move the camera, and include real visibility setters.
		var position := Vector3(iteration % 80, 0, 10)
		for variant in ([0, 1] if iteration % 2 == 0 else [1, 0]):
			for entry in controller.distance_nodes:
				entry.node.visible = true
			var started := Time.get_ticks_usec()
			while true:
				if variant == 0:
					controller.reference_scan(position, Time.get_ticks_usec())
				else:
					controller.update_distance_visibility(position, Time.get_ticks_usec())
				if controller.cull_cursor == 0:
					break
			var elapsed := Time.get_ticks_usec() - started
			if iteration >= 20:
				samples["per_entry_clock_us" if variant == 0 else "batch16_clock_us"].append(elapsed)
			for entry in controller.distance_nodes:
				assert(entry.node.visible == (position.distance_squared_to(entry.center) < 900.0))
	print("DISTANCE_CPU_SAMPLES ", JSON.stringify(samples))
	print("DISTANCE_CPU_PASS")
	for entry in controller.distance_nodes:
		entry.node.free()
	controller.free()
	quit()
