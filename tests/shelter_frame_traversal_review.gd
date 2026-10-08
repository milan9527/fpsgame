extends SceneTree

# Independent packaged-game diagnostic: exercise the real actor movement,
# including gravity and doorway floor transitions, rather than ray clearance.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var failed := false
	# Both routes must fit the current rear portal (x=14.2..16.8),
	# including the actor capsule. Old routes intersected the parked doors/wall.
	for route_x in [15.0, 16.0]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(route_x, 0.3, 30.5 - direction * 6.5)
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			var start: Vector3 = actor.position
			actor.move_input = Vector2(0, direction)
			for frame in range(360):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if (actor.position.z - 30.5) * direction > 6.1:
					break
			var passed: bool = (actor.position.z - 30.5) * direction > 6.1
			failed = failed or not passed
			results.append({"route_x": route_x, "direction": direction, "start": str(start),
				"end": str(actor.position), "passed": passed})
	# Actual capsule checks at both masonry feet: head-on stop and inner-edge bypass.
	for post_x in [12.24, 18.76]:
		for bypass in [false, true]:
			var offset: float = (0.68 if post_x < 15.5 else -0.68) if bypass else 0.0
			actor.position = Vector3(post_x + offset, 0.3, 36.5)
			actor.velocity = Vector3.ZERO
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			actor.move_input = Vector2(0, -1)
			for frame in range(100):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if actor.position.z < 34.1:
					break
			var passed: bool = actor.position.z < 34.1 if bypass else actor.position.z > 35.35 and actor.position.z < 36.0
			failed = failed or not passed
			results.append({"porch_foot_x": post_x, "bypass": bypass, "end": str(actor.position), "passed": passed})
	actor.move_input = Vector2.ZERO
	var space = world.get_world_3d().direct_space_state
	# Headroom remains clear while the raised curtain stops high shots.
	for height in [2.6, 3.1]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(15.5, height, 34), Vector3(15.5, height, 32.5), 1))
		var passed: bool = hit.is_empty() if height < 2.8 else (
			not hit.is_empty() and absf(hit.position.z - 33.1575) < 0.06)
		failed = failed or not passed
		results.append({"shutter_headroom": height, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for door_x in [12.9, 15.5, 18.1]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(door_x, 1.4, 34), Vector3(door_x, 1.4, 32.5), 1))
		var passed: bool = hit.is_empty() if door_x == 15.5 else (
			not hit.is_empty() and absf(hit.position.z - 33.18) < 0.06)
		failed = failed or not passed
		results.append({"door_x": door_x, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# Folded steel jambs bound the 3.8 m entrance at x=13.60 and x=17.40.
	# Check both solid sides as well as the unchanged inner masonry and roof.
	for probe in [{"from": Vector3(15.5,1,33.03), "to": Vector3(11,1,33.03), "axis": "x", "expected": 13.60}, {"from": Vector3(15.5,1,33.03), "to": Vector3(20,1,33.03), "axis": "x", "expected": 17.40}, {"from": Vector3(15.5,1,29.5), "to": Vector3(11,1,29.5), "axis": "x", "expected": 12.26}, {"from": Vector3(15.5,4,29.5), "to": Vector3(15.5,6,29.5), "axis": "y", "expected": 5.175}]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(probe.from, probe.to, 1))
		var passed: bool = not hit.is_empty() and absf(hit.position[probe.axis] - probe.expected) < 0.06
		failed = failed or not passed
		results.append({"collision_axis": probe.axis, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# Walk into the new porch screen with the real capsule; the central routes
	# above must still pass while the west-side timber stops lateral movement.
	actor.position = Vector3(13.4, 0.3, 34.18)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	actor.move_input = Vector2(-1, 0)
	for frame in range(120):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var screen_passed: bool = actor.position.x > 12.3 and actor.position.x < 13.0
	failed = failed or not screen_passed
	results.append({"porch_screen_capsule": str(actor.position), "passed": screen_passed})
	actor.move_input = Vector2.ZERO
	# Raised masonry and the new continuous glazing both stop shots.
	# Probe the former slat gap to catch transparent-but-nonphysical panes.
	for height in [1.0, 1.55, 1.78, 1.88]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(13, height, 34.18), Vector3(11.8, height, 34.18), 1))
		var expected_x: float = 12.42 if height == 1.0 else 12.2575
		var passed: bool = (
			not hit.is_empty() and absf(hit.position.x - expected_x) < 0.04)
		failed = failed or not passed
		results.append({"porch_screen_height": height, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for pier_x in [12.24, 18.76]:
		for height in [0.8, 2.4]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(pier_x, height, 36), Vector3(pier_x, height, 34.8), 1))
			# Single masonry pier: center z=35, depth=0.36; the duplicate shoe is removed.
			var expected_z: float = 35.18 if height == 0.8 else 35.196
			var passed: bool = not hit.is_empty() and absf(hit.position.z - expected_z) < 0.02
			failed = failed or not passed
			results.append({"pier_x": pier_x, "height": height,
				"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
		# Offset from the existing I-beam flange to isolate the new square post.
		var steel_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(pier_x + 0.06, 2.0, 36), Vector3(pier_x + 0.06, 2.0, 34.8), 1))
		var steel_passed: bool = not steel_hit.is_empty() and absf(steel_hit.position.z - 35.065) < 0.01
		failed = failed or not steel_passed
		results.append({"slender_post_x": pier_x + 0.06, "hit": str(steel_hit.get("position", Vector3.ZERO)), "passed": steel_passed})
		# At 2 m the side gap is below the knee braces.
		var opening_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(pier_x + 0.13, 2.0, 36), Vector3(pier_x + 0.13, 2.0, 34.8), 1))
		failed = failed or not opening_hit.is_empty()
		results.append({"pier_side_opening_x": pier_x + 0.13, "passed": opening_hit.is_empty()})
		# Probe the retained diagonal at its midpoint, clear of the post and beam.
		var brace_x: float = pier_x + (0.35 if pier_x < 15.5 else -0.35)
		var brace_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(brace_x, 2.63, 36), Vector3(brace_x, 2.63, 34.8), 1))
		var brace_passed: bool = not brace_hit.is_empty() and absf(brace_hit.position.z - 35.0525) < 0.015
		failed = failed or not brace_passed
		results.append({"brace_midpoint_x": brace_x, "hit": str(brace_hit.get("position", Vector3.ZERO)), "passed": brace_passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	# Probe the clear glass away from steel jambs: transparent panes must still
	# stop actors/projectiles on both sides of all three window bays.
	for side in [-1.0, 1.0]:
		for pane_z in [27.6, 29.9, 32.1]:
			var wall_x: float = 15.5 + side * 3.3
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
				Vector3(wall_x + side * 0.8, 1.45, pane_z),
				Vector3(wall_x - side * 0.8, 1.45, pane_z), 1))
			var passed: bool = not hit.is_empty() and absf(hit.position.x - (wall_x + side * 0.06)) < 0.025
			failed = failed or not passed
			results.append({"window_side": side, "pane_z": pane_z,
				"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("shelter-frame-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "passed": not failed}, "\t"))
	file.close()
	print("SHELTER_FRAME_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
