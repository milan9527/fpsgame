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
		{"name": "new_east_grass_bank", "a": Vector3(21.8, 0.3, 37), "b": Vector3(21.8, 0.3, 44.9)},
		{"name": "cross_new_grass_bank", "a": Vector3(18.5, 0.3, 41.3), "b": Vector3(25.5, 0.3, 41.3)},
		{"name": "eroded_west_shoulder", "a": Vector3(8.7, 0.3, 41), "b": Vector3(13.3, 0.3, 41)}]
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
					passed = passed and peak_height > 0.60
				if route.name == "eroded_west_shoulder" and mode != "bot":
					passed = passed and peak_height > 0.25 and peak_height < 0.70
				failed = failed or not passed
				results.append({"route": route.name, "mode": mode, "reverse": reverse, "start": str(start), "goal": str(goal), "end": str(actor.position), "passed": passed, "peak_height": peak_height, "seconds": frames / 60.0, "repaths": nav.repaths, "peak_stuck_time": peak_stuck})
				print("LANE_ROUTE ", JSON.stringify(results[-1]))
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("stage317-berm-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes": results, "navigation_ready": world.navigation_ready(), "passed": not failed}, "\t"))
	file.close()
	print("STAGE317_BERM_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
