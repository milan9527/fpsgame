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
	for route in [
		["enter_open_front", Vector3(12, 0.3, 84), Vector2(1,0), 40, 15.0, 16.5],
		["leave_open_front", Vector3(16, 0.3, 84), Vector2(-1,0), 80, 8.0, 10.0]]:
		actor.position = route[1]
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(20):
			await physics_frame
			actor.move_step(1.0/60.0)
		actor.move_input = route[2]
		for frame in range(route[3]):
			await physics_frame
			actor.move_step(1.0/60.0)
		var passed: bool = actor.position.x > route[4] and actor.position.x < route[5]
		failed = failed or not passed
		results.append({"route":route[0],"start":str(route[1]),"end":str(actor.position),"passed":passed})
	for probe in [
		["lower_windbreak",Vector3(16,0.8,86.5),Vector3(19,0.8,86.5),true],
		["upper_slat",Vector3(16,1.8,83.85),Vector3(19,1.8,83.85),true],
		["pitched_roof",Vector3(16,5,84),Vector3(16,2.5,84),true],
		["bench_top",Vector3(17.25,1.5,84),Vector3(17.25,0.3,84),true],
		["open_entrance",Vector3(12,1.5,84),Vector3(16,1.5,84),false]]:
		var query := PhysicsRayQueryParameters3D.create(probe[1],probe[2],1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = (not hit.is_empty()) == probe[3]
		failed = failed or not passed
		results.append({"probe":probe[0],"hit":str(hit.get("position",Vector3.ZERO)),"passed":passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("waiting-shelter-traversal.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"passed":not failed},"\t"))
	file.close()
	print("WAITING_SHELTER_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
