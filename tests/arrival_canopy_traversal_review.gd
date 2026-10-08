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
		["front_to_rear", Vector3(-12, 0.3, 73), Vector2(0,-1), 180, 55.0, 59.0],
		["rear_to_front", Vector3(-12, 0.3, 57), Vector2(0,1), 180, 71.0, 75.0],
		["main_road", Vector3(0, 0.3, 80), Vector2(0,-1), 180, 62.0, 66.0]]:
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
		var passed: bool = actor.position.z > route[4] and actor.position.z < route[5]
		failed = failed or not passed
		results.append({"route":route[0],"start":str(route[1]),"end":str(actor.position),"passed":passed})
	for probe in [
		["brick_wall",Vector3(-14,1,65),Vector3(-16,1,65),true],
		["pitched_roof",Vector3(-12,5,65),Vector3(-12,2,65),true],
		["entrance_post",Vector3(-9,1,71),Vector3(-9,1,69),true],
		["workbench_top",Vector3(-14.25,1.5,66),Vector3(-14.25,0.5,66),true],
		["work_wall",Vector3(-14,1.9,65),Vector3(-16,1.9,65),true],
		["clerestory_opening",Vector3(-14,2.8,66),Vector3(-16,2.8,66),false],
		["open_aisle",Vector3(-12,1.5,72),Vector3(-12,1.5,58),false]]:
		var query := PhysicsRayQueryParameters3D.create(probe[1],probe[2],1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = (not hit.is_empty()) == probe[3]
		failed = failed or not passed
		results.append({"probe":probe[0],"hit":str(hit.get("position",Vector3.ZERO)),"passed":passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("arrival-canopy-traversal.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"results":results,"passed":not failed},"\t"))
	file.close()
	print("ARRIVAL_CANOPY_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
