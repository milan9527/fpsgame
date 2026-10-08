extends SceneTree

# Exercise real capsule movement; a navigation path alone is not a pass.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	var routes := [
		{"name": "drainage_road_to_entry_gap", "a": Vector3(7.5, 0.3, 37), "b": Vector3(15.5, 0.3, 37)},
		{"name": "drainage_south_crossing", "a": Vector3(7.5, 0.3, 48), "b": Vector3(12, 0.3, 48)},
		{"name": "drainage_roadside_clearance", "a": Vector3(8.0, 0.3, 26), "b": Vector3(8.0, 0.3, 46)},
		{"name": "grove_vertical_road", "a": Vector3(6, 0.3, 12), "b": Vector3(6, 0.3, 24)},
		{"name": "grove_cross_road", "a": Vector3(10, 0.3, 5), "b": Vector3(24, 0.3, 5)},
		# The existing fence spans x=10..21 at z=22; enter through its
		# x=21..26 gate, then approach the rear door from inside the yard.
		{"name": "grove_fence_gate", "a": Vector3(23.5, 0.3, 20), "b": Vector3(23.5, 0.3, 24)},
		{"name": "grove_gate_to_rear", "a": Vector3(23.5, 0.3, 24), "b": Vector3(15.5, 0.3, 24)},
		{"name": "grove_rear_approach", "a": Vector3(15.5, 0.3, 24), "b": Vector3(15.5, 0.3, 27)},
		{"name": "east_grass_bank", "a": Vector3(24, 0.3, 54), "b": Vector3(24, 0.3, 44)},
		{"name": "west_grass_bank", "a": Vector3(10.5, 0.3, 46), "b": Vector3(10.5, 0.3, 34)},
		{"name": "shoulders", "a": Vector3(12, 0.3, 43), "b": Vector3(20, 0.3, 43)},
		{"name": "bend", "a": Vector3(10, 0.3, 46), "b": Vector3(16, 0.3, 53)},
		{"name": "north_end", "a": Vector3(11.5, 0.3, 37), "b": Vector3(19.5, 0.3, 37)},
		{"name": "south_end", "a": Vector3(6, 0.3, 49), "b": Vector3(12, 0.3, 55)},
		{"name": "shelter_entry", "a": Vector3(15.5, 0.3, 27), "b": Vector3(15.5, 0.3, 45)}]
	var results := []
	var failed := false
	world.prepare_navigation()
	for tick in range(180):
		await physics_frame
		if world.navigation_ready():
			break
	for mode in ["standing", "crouched", "bot"]:
		for route in routes:
			for reverse in [false, true]:
				var start: Vector3 = route.b if reverse else route.a
				var goal: Vector3 = route.a if reverse else route.b
				actor.position = start
				actor.velocity = Vector3.ZERO
				actor.yaw = 0
				actor.crouch = mode == "crouched"
				actor.jump_requested = false
				actor.move_input = Vector2.ZERO
				for frame in range(30):
					await physics_frame
					actor.move_step(1.0 / 60.0)
				var nav = load("res://scripts/bot_navigator.gd").new()
				var passed := false
				var frames := 0
				var peak_stuck := 0.0
				var peak_height: float = actor.position.y
				for frame in range(600):
					await physics_frame
					var delta: Vector3 = goal - actor.position
					delta.y = 0
					if delta.length() < 0.65:
						passed = true
						break
					var steer: Vector3 = nav.steer(actor, world, goal, 1.0 / 60.0, 0.5) if mode == "bot" else delta.normalized()
					actor.move_input = Vector2(steer.x, steer.z)
					actor.move_step(1.0 / 60.0)
					peak_height = maxf(peak_height, actor.position.y)
					frames += 1
					peak_stuck = maxf(peak_stuck, nav.stuck_time)
				# Direct routes must actually climb the visible bank, not pass
				# beneath a missing or inverted terrain collision surface.
				if route.name.ends_with("grass_bank") and mode != "bot":
					if route.name == "west_grass_bank":
						# Stage325 lowered and eroded this shoulder. Still require
						# real capsule elevation, and reject the former tall bank.
						passed = passed and peak_height > 0.25 and peak_height < 0.70
					else:
						passed = passed and peak_height > 0.60
				failed = failed or not passed
				results.append({"route": route.name, "mode": mode, "reverse": reverse, "start": str(start), "goal": str(goal), "end": str(actor.position), "passed": passed, "peak_height": peak_height, "seconds": frames / 60.0, "repaths": nav.repaths, "peak_stuck_time": peak_stuck})
				print("LANE_ROUTE ", JSON.stringify(results[-1]))
	# The new retaining edge must stop a real capsule as well as bullets.
	actor.position = Vector3(7.8, 0.3, 44)
	actor.velocity = Vector3.ZERO
	actor.crouch = false
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	for frame in range(120):
		await physics_frame
		actor.move_input = Vector2(1, 0)
		actor.move_step(1.0 / 60.0)
	var wall_blocks: bool = actor.position.x < 9.15 and actor.position.x > 8.1
	var ray := PhysicsRayQueryParameters3D.create(Vector3(8.4, 0.4, 44), Vector3(9.8, 0.4, 44))
	ray.exclude = [actor.get_rid()]
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	var stone_hit: bool = not hit.is_empty() and hit.collider.get_parent().has_meta("road_drain_retaining")
	failed = failed or not wall_blocks or not stone_hit
	results.append({"route": "retaining_wall_collision", "end": str(actor.position),
		"capsule_blocked": wall_blocks, "stone_ray_hit": stone_hit, "passed": wall_blocks and stone_hit})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("service-lane-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "navigation_ready": world.navigation_ready(), "passed": not failed}, "\t"))
	file.close()
	print("SERVICE_LANE_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
