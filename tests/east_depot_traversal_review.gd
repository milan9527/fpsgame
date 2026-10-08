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
	for route_x in [33.8, 35.0, 36.2]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(route_x, 0.3, 34.0 - direction * 10.0)
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			actor.move_input = Vector2(0, direction)
			for frame in range(420):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if (actor.position.z - 34.0) * direction > 9.5:
					break
			var passed: bool = (actor.position.z - 34.0) * direction > 9.5
			failed = failed or not passed
			var contacts := []
			for index in range(actor.get_slide_collision_count()):
				var hit = actor.get_slide_collision(index)
				var body = hit.get_collider()
				contacts.append({"body":str(body.get_path()),"origin":str(body.global_position),"point":str(hit.get_position()),"normal":str(hit.get_normal())})
			results.append({"x":route_x,"direction":direction,"end":str(actor.position),"passed":passed,"contacts":contacts})
	var output = FileAccess.open(OS.get_environment("CAPTURE_ARTIFACT_DIR") + "/east-depot-clearance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results,"  "))
	print("EAST_DEPOT_CLEARANCE ", "FAIL" if failed else "PASS", " routes=6")
	quit(1 if failed else 0)
