extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var results := []
	var failed := false
	# Traverse both doors, slab ramps and the new canopy with real movement.
	for direction in [-1.0, 1.0]:
		actor.position = Vector3(-42, 0.3, 34 - direction * 14)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var start: Vector3 = actor.position
		actor.move_input = Vector2(0, direction)
		for frame in range(420):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if (actor.position.z - 34) * direction > 13.5:
				break
		var passed: bool = (actor.position.z - 34) * direction > 13.5
		failed = failed or not passed
		results.append({"direction": direction, "start": str(start),
			"end": str(actor.position), "passed": passed})
	# Crouched passage near both doorway edges exercises the actual capsule,
	# ramp and stance, not just an unobstructed ray down the center.
	actor.crouch = true
	for edge_x in [-43.2, -40.8]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(edge_x, 0.3, 44 if direction < 0 else 38)
			actor.velocity = Vector3.ZERO
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			actor.move_input = Vector2(0, direction)
			for frame in range(180):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if (actor.position.z - 41) * direction > 2.8:
					break
			var crouch_passed: bool = actor.crouched and (actor.position.z - 41) * direction > 2.8
			failed = failed or not crouch_passed
			results.append({"crouched_edge_x": edge_x, "direction": direction,
				"end": str(actor.position), "passed": crouch_passed})
	actor.crouch = false
	# Physically walk into a new column, then verify roof/column shot collision.
	actor.position = Vector3(-39.2, 0.3, 48)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	for frame in range(180):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var column_stops_actor: bool = actor.position.z > 45.1 and actor.position.z < 45.7
	failed = failed or not column_stops_actor
	results.append({"column_stops_actor": column_stops_actor, "end": str(actor.position)})
	actor.position = Vector3(-37.45, 0.3, 32)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	for frame in range(120):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var rack_stops_actor: bool = actor.position.z > 29.3 and actor.position.z < 29.9
	failed = failed or not rack_stops_actor
	results.append({"parts_rack_stops_actor": rack_stops_actor, "end": str(actor.position)})
	# Approach the exposed worktop edge with the actual character capsule.
	actor.position = Vector3(-46.9, 0.3, 30.5)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	for frame in range(120):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var bench_stops_actor: bool = actor.position.z > 28.55 and actor.position.z < 29.15
	failed = failed or not bench_stops_actor
	results.append({"workbench_stops_actor": bench_stops_actor, "end": str(actor.position)})
	# Stage204: the repair bay's open aisle remains usable in both directions.
	for direction in [-1.0, 1.0]:
		actor.position = Vector3(-29, 0.3, 44 if direction < 0 else 28)
		actor.velocity = Vector3.ZERO
		actor.move_input = Vector2.ZERO
		for frame in range(30):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		actor.move_input = Vector2(0, direction)
		for frame in range(300):
			await physics_frame
			actor.move_step(1.0 / 60.0)
			if actor.position.z < 28.5 if direction < 0 else actor.position.z > 43.5:
				break
		var bay_passed: bool = actor.position.z < 28.5 if direction < 0 else actor.position.z > 43.5
		failed = failed or not bay_passed
		results.append({"service_bay_direction": direction, "end": str(actor.position), "passed": bay_passed})
	# Cross the flush drain and feathered verge through both open bays, with
	# actual standing/crouched capsules in both directions.
	for crouched in [false, true]:
		actor.crouch = crouched
		for lane_z in [30.5, 36.5]:
			for direction in [-1.0, 1.0]:
				actor.position = Vector3(-22.8 if direction < 0 else -30.0, 0.3, lane_z)
				actor.velocity = Vector3.ZERO
				actor.move_input = Vector2.ZERO
				for frame in range(30):
					await physics_frame
					actor.move_step(1.0 / 60.0)
				actor.move_input = Vector2(direction, 0)
				for frame in range(300):
					await physics_frame
					actor.move_step(1.0 / 60.0)
					if actor.position.x < -29.5 if direction < 0 else actor.position.x > -23.3:
						break
				var crossed: bool = actor.position.x < -29.5 if direction < 0 else actor.position.x > -23.3
				failed = failed or not crossed
				results.append({"drain_crossing_z": lane_z, "crouched": crouched,
					"direction": direction, "end": str(actor.position), "passed": crossed})
	actor.crouch = false
	# Stage353: the replacement parts rack must stop the real player capsule.
	actor.position = Vector3(-31, 0.3, 29)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	actor.move_input = Vector2(-1, 0)
	for frame in range(120):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var rack_stopped: bool = actor.position.x > -32.5 and actor.position.x < -31.8
	failed = failed or not rack_stopped
	results.append({"parts_rack_capsule": true, "end": str(actor.position), "passed": rack_stopped})
	actor.move_input = Vector2.ZERO
	var space = world.get_world_3d().direct_space_state
	var rays := []
	var bay_rack_query := PhysicsRayQueryParameters3D.create(
		Vector3(-32, 0.86, 29), Vector3(-33, 0.86, 29), 1)
	bay_rack_query.exclude = [actor.get_rid()]
	var bay_rack_hit: Dictionary = space.intersect_ray(bay_rack_query)
	var bay_rack_passed: bool = not bay_rack_hit.is_empty() and absf(bay_rack_hit.position.x + 32.53) < 0.025
	failed = failed or not bay_rack_passed
	rays.append({"parts_rack_shelf": true, "hit": str(bay_rack_hit.get("position", Vector3.ZERO)), "passed": bay_rack_passed})
	# Glazing admits sunlight but remains solid. Sample away from the
	# purlins and kerbs so these cannot hide a missing pane collider.
	for pane_z in [31.0, 36.8]:
		for x in [-31.5, -28.5]:
			for side in [-1.0, 1.0]:
				var center := Vector3(x, 3.78 - (x + 30) * tan(0.12), pane_z)
				var query := PhysicsRayQueryParameters3D.create(
					center + Vector3(0, side * 0.25, 0),
					center - Vector3(0, side * 0.25, 0), 1)
				query.exclude = [actor.get_rid()]
				var hit: Dictionary = space.intersect_ray(query)
				var passed: bool = not hit.is_empty() and absf(hit.position.y - center.y) < 0.025
				failed = failed or not passed
				rays.append({"skylight_z": pane_z, "sample_x": x, "side": side,
					"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for endpoints in [
		[Vector3(-30, 3, 35), Vector3(-30, 4.5, 35)],
		[Vector3(-25, 1.5, 27), Vector3(-26.15, 1.5, 27)],
		[Vector3(-25, 3.32, 35), Vector3(-26.15, 3.32, 35)]]:
		var query := PhysicsRayQueryParameters3D.create(endpoints[0], endpoints[1], 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var passed := not hit.is_empty()
		failed = failed or not passed
		rays.append({"service_bay_from": str(endpoints[0]), "to": str(endpoints[1]), "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# Stage194 worktop is a solid surface at its visible front edge.
	var bench_query := PhysicsRayQueryParameters3D.create(
		Vector3(-46.9, 0.92, 29), Vector3(-46.9, 0.92, 27.5), 1)
	bench_query.exclude = [actor.get_rid()]
	var bench_hit: Dictionary = space.intersect_ray(bench_query)
	var bench_passed: bool = not bench_hit.is_empty() and absf(bench_hit.position.z - 28.505) < 0.02
	failed = failed or not bench_passed
	rays.append({"workbench_front": true, "hit": str(bench_hit.get("position", Vector3.ZERO)),
		"passed": bench_passed})
	# Stage191 facade returns and drains must stop shots at their visible face.
	for sample in [
		Vector3(-49.72, 1.65, 41.36), Vector3(-34.28, 1.65, 41.36),
		Vector3(-49.48, 2.22, 41.35), Vector3(-44.52, 2.22, 41.35),
		Vector3(-39.48, 2.22, 41.35), Vector3(-34.52, 2.22, 41.35)]:
		var facade_query := PhysicsRayQueryParameters3D.create(
			sample + Vector3(0, 0, 0.5), sample - Vector3(0, 0, 0.1), 1)
		facade_query.exclude = [actor.get_rid()]
		var facade_hit: Dictionary = space.intersect_ray(facade_query)
		var facade_passed: bool = not facade_hit.is_empty() and absf(facade_hit.position.z - sample.z) < 0.02
		failed = failed or not facade_passed
		rays.append({"facade_sample": str(sample), "hit": str(facade_hit.get("position", Vector3.ZERO)),
			"passed": facade_passed})
	# Sample the centre of each opaque window pane, clear of the mullions.
	# These panels cover solid facade and must stop shots at their own surface.
	for pane_x in [-46.4, -36.4]:
		var pane_query := PhysicsRayQueryParameters3D.create(
			Vector3(pane_x, 2.6, 42), Vector3(pane_x, 2.6, 40), 1)
		pane_query.exclude = [actor.get_rid()]
		var pane_hit: Dictionary = space.intersect_ray(pane_query)
		var pane_passed: bool = not pane_hit.is_empty() and absf(pane_hit.position.z - 41.11) < .02
		failed = failed or not pane_passed
		rays.append({"window_pane_x": pane_x,
			"hit": str(pane_hit.get("position", Vector3.ZERO)), "passed": pane_passed})
	# Downpipes sit outside the walking lane, but their visible metal must
	# stop a shot rather than behave as decorative, pass-through geometry.
	for pipe_x in [-49.55, -34.45]:
		var pipe_query := PhysicsRayQueryParameters3D.create(
			Vector3(pipe_x, 1.5, 46), Vector3(pipe_x, 1.5, 45), 1)
		pipe_query.exclude = [actor.get_rid()]
		var pipe_hit: Dictionary = space.intersect_ray(pipe_query)
		var pipe_passed: bool = not pipe_hit.is_empty() and absf(pipe_hit.position.z - 45.53) < 0.02
		failed = failed or not pipe_passed
		rays.append({"downpipe_x": pipe_x, "hit": str(pipe_hit.get("position", Vector3.ZERO)),
			"passed": pipe_passed})
	var cabinet_query := PhysicsRayQueryParameters3D.create(
		Vector3(-44.65, 1.55, 43), Vector3(-44.65, 1.55, 40), 1)
	cabinet_query.exclude = [actor.get_rid()]
	var cabinet_hit: Dictionary = space.intersect_ray(cabinet_query)
	var cabinet_passed: bool = not cabinet_hit.is_empty() and absf(cabinet_hit.position.z - 41.30) < 0.02
	failed = failed or not cabinet_passed
	rays.append({"electrical_cabinet": true, "hit": str(cabinet_hit.get("position", Vector3.ZERO)),
		"passed": cabinet_passed})
	# Rear-right parts shelf must stop shots at its visible front edge.
	var rack_query := PhysicsRayQueryParameters3D.create(
		Vector3(-37.45, 1.25, 31), Vector3(-37.45, 1.25, 28), 1)
	rack_query.exclude = [actor.get_rid()]
	var rack_hit: Dictionary = space.intersect_ray(rack_query)
	var rack_passed: bool = not rack_hit.is_empty() and absf(rack_hit.position.z - 29.25) < 0.02
	failed = failed or not rack_passed
	rays.append({"parts_rack": true, "hit": str(rack_hit.get("position", Vector3.ZERO)),
		"passed": rack_passed})
	# The new brick skin must stop shots at its visible front, while the
	# full-height centre opening remains covered by the walking routes above.
	for x in [-46.85, -37.15]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 0.65, 41.5), Vector3(x, 0.65, 39.5), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var passed: bool = not hit.is_empty() and absf(hit.position.z - 41.03) < 0.02
		failed = failed or not passed
		rays.append({"brick_front_x": x, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for endpoints in [
		[Vector3(-38, 1, 45), Vector3(-40, 1, 45), 0],
		[Vector3(-42, 2, 43), Vector3(-42, 5, 43), 1]]:
		var query := PhysicsRayQueryParameters3D.create(endpoints[0], endpoints[1], 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		var passed := not hit.is_empty()
		if passed:
			passed = absf(hit.position.x + 39.135) < 0.02 if endpoints[2] == 0 else hit.position.y > 3.4 and hit.position.y < 3.8
		failed = failed or not passed
		rays.append({"from": str(endpoints[0]), "to": str(endpoints[1]),
			"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# Probe only the thin pitched hood, avoiding the older roof above it.
	var hood := world.find_child("WorkshopRainHood", true, false) as MeshInstance3D
	if hood == null:
		failed = true
		rays.append({"rainhood_missing": true, "passed": false})
	else:
		for sample in [Vector3.ZERO, Vector3(-2.15, 0, 0), Vector3(2.15, 0, 0), Vector3(0, 0, -.45), Vector3(0, 0, .45)]:
			for side in [-1.0, 1.0]:
				var centre: Vector3 = hood.to_global(sample)
				var normal: Vector3 = hood.global_basis.y.normalized() * side
				var origin: Vector3 = centre + normal * .18
				var query := PhysicsRayQueryParameters3D.create(origin, centre - normal * .18, 1)
				query.exclude = [actor.get_rid()]
				var hit: Dictionary = space.intersect_ray(query)
				var passed: bool = not hit.is_empty() and hit.collider.get_parent() == hood and absf(origin.distance_to(hit.position) - .1525) < .005
				failed = failed or not passed
				rays.append({"rainhood_local_sample": str(sample), "side": side,
					"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# Stage207: both sloped monitor panels stop shots at the visible roof.
	# Sample between decorative ribs; a stale flat cap would miss this height.
	for building_x in [-42.0, 35.0]:
		for side in [-1.0, 1.0]:
			var origin := Vector3(building_x + side * .975, 8.5, 34.35)
			var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0, 1.2, 0), 1)
			query.exclude = [actor.get_rid()]
			var hit: Dictionary = space.intersect_ray(query)
			var passed: bool = not hit.is_empty() and absf(hit.position.y - 7.646) < .01
			failed = failed or not passed
			rays.append({"monitor_building_x": building_x, "slope_side": side,
				"hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("west-workshop-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "rays": rays, "passed": not failed}, "\t"))
	file.close()
	print("WEST_WORKSHOP_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
