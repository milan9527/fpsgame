extends SceneTree
## CPU microbenchmark only: these are not presented frame times or Android FPS.
const Profile = preload("res://scripts/mobile_performance.gd")

class BenchmarkProfile extends Profile:
	func reference_scan(camera_position: Vector3, cull_started: int) -> void:
		if cull_cursor == 0:
			cull_pass_position = camera_position
			cull_pass_stable = true
			cull_settled = false
		elif camera_position != cull_pass_position:
			cull_pass_stable = false
		# Check the clock once per small batch, instead of once per world object.
		# The 1 ms soft budget can overrun by at most the remaining 15 entries.
		# Static entries do not change during this synchronous scan. Keep the
		# entry count local instead of querying the array twice per batch.
		var entry_count := distance_nodes.size()
		# All grass batches use the same horizontal camera position this pass.
		var camera_xz := Vector2(camera_position.x, camera_position.z)
		while cull_cursor < entry_count:
			var batch_end := mini(cull_cursor + 16, entry_count)
			while cull_cursor < batch_end:
				var entry: DistanceEntry = distance_nodes[cull_cursor]
				var shown: bool
				if entry.grass_fade_squared > 0.0:
					# Match the shader's horizontal root distance. The older 3D
					# center limit can hide near blades in wide or sloped patches.
					shown = entry.grass_in_range_xz(camera_xz)
				else:
					var distance_squared := camera_position.distance_squared_to(entry.center)
					shown = distance_squared >= entry.begin_squared and distance_squared < entry.end_squared
				if entry.node.visible != shown:
					entry.node.visible = shown
				cull_cursor += 1
			if Time.get_ticks_usec() - cull_started >= 1000:
				break
		if cull_cursor >= entry_count:
			cull_cursor = 0
			cull_seconds = 0.05
			# A pass spanning camera movement has mixed results. Complete another
			# pass at the stopped position before suppressing stationary scans.
			cull_settled = cull_pass_stable and not baseline_running
			cull_settled_position = camera_position
			cull_settled_count = entry_count

	func experimental_scan(camera_position: Vector3, cull_started: int) -> void:
		if cull_cursor == 0:
			cull_pass_position = camera_position
			cull_pass_stable = true
			cull_settled = false
		elif camera_position != cull_pass_position:
			cull_pass_stable = false
		# Check the clock once per small batch, instead of once per world object.
		# The 1 ms soft budget can overrun by at most the remaining 15 entries.
		# Static entries do not change during this synchronous scan. Keep the
		# entry count local instead of querying the array twice per batch.
		var entry_count := distance_nodes.size()
		# All grass batches use the same horizontal camera position this pass.
		var camera_xz := Vector2(camera_position.x, camera_position.z)
		# Publish the resumable cursor once per slice, not for every entry.
		var cursor := cull_cursor
		while cursor < entry_count:
			var batch_end := mini(cursor + 16, entry_count)
			while cursor < batch_end:
				var entry: DistanceEntry = distance_nodes[cursor]
				var shown: bool
				if entry.grass_fade_squared > 0.0:
					# Match the shader's horizontal root distance. The older 3D
					# center limit can hide near blades in wide or sloped patches.
					shown = entry.grass_in_range_xz(camera_xz)
				else:
					var distance_squared := camera_position.distance_squared_to(entry.center)
					shown = distance_squared >= entry.begin_squared and distance_squared < entry.end_squared
				if entry.node.visible != shown:
					entry.node.visible = shown
				cursor += 1
			if Time.get_ticks_usec() - cull_started >= 1000:
				break
		cull_cursor = cursor
		if cull_cursor >= entry_count:
			cull_cursor = 0
			cull_seconds = 0.05
			# A pass spanning camera movement has mixed results. Complete another
			# pass at the stopped position before suppressing stationary scans.
			cull_settled = cull_pass_stable and not baseline_running
			cull_settled_position = camera_position
			cull_settled_count = entry_count

func _initialize() -> void:
	var controller = BenchmarkProfile.new()
	for index in range(4099):
		var node := Node3D.new()
		controller.distance_nodes.append(Profile.DistanceEntry.new(
			node, Vector3(index % 100, 0, index / 100), 0.0, 30.0))
	# An expired budget must yield after one batch, retain its cursor,
	# and eventually visit the final partial batch.
	controller.experimental_scan(Vector3.ZERO, Time.get_ticks_usec() - 2000)
	assert(controller.cull_cursor == 16)
	var calls := 1
	while controller.cull_cursor != 0:
		controller.experimental_scan(Vector3.ZERO, Time.get_ticks_usec() - 2000)
		calls += 1
	assert(calls == 257)
	for entry in controller.distance_nodes:
		assert(entry.node.visible == (entry.center.length_squared() < 900.0))
	var samples := {"previous_scan_us": [], "local_cursor_scan_us": []}
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
					controller.experimental_scan(position, Time.get_ticks_usec())
				if controller.cull_cursor == 0:
					break
			var elapsed := Time.get_ticks_usec() - started
			if iteration >= 20:
				samples["previous_scan_us" if variant == 0 else "local_cursor_scan_us"].append(elapsed)
			for entry in controller.distance_nodes:
				assert(entry.node.visible == (position.distance_squared_to(entry.center) < 900.0))
	print("DISTANCE_CPU_SAMPLES ", JSON.stringify(samples))
	print("DISTANCE_CPU_PASS")
	for entry in controller.distance_nodes:
		entry.node.free()
	controller.free()
	quit()
