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
	var routes := [[Vector3(-29,0.3,28),Vector3(-29,0.3,42)], [Vector3(-31,0.3,30.5),Vector3(-24,0.3,30.5)], [Vector3(-31,0.3,36.5),Vector3(-24,0.3,36.5)]]
	for route in routes:
		for reverse in [false,true]:
			var start: Vector3 = route[1] if reverse else route[0]
			var finish: Vector3 = route[0] if reverse else route[1]
			actor.position = start
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			var direction := (finish-start).normalized()
			actor.move_input = Vector2(direction.x,direction.z)
			for frame in range(420):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if Vector2(actor.position.x-finish.x,actor.position.z-finish.z).length() < 0.4:
					break
			var passed: bool = Vector2(actor.position.x-finish.x,actor.position.z-finish.z).length() < 0.4
			failed = failed or not passed
			results.append({"start":str(start),"target":str(finish),"end":str(actor.position),"passed":passed})
	actor.move_input = Vector2.ZERO
	var probes := [
		["post",Vector3(-27,1.5,33.5),Vector3(-25.5,1.5,33.5),true],
		["rear_wall",Vector3(-30,1,27),Vector3(-30,1,26),true],
		["bench_open",Vector3(-33.4,0.55,29),Vector3(-32,0.55,29),false],
		["bench_top",Vector3(-33.4,0.86,29),Vector3(-32,0.86,29),true]]
	for probe in probes:
		var query = PhysicsRayQueryParameters3D.create(probe[1],probe[2])
		query.exclude = [actor.get_rid()]
		var hit = root.world_3d.direct_space_state.intersect_ray(query)
		var passed: bool = (not hit.is_empty()) == probe[3]
		failed = failed or not passed
		results.append({"probe":probe[0],"hit":not hit.is_empty(),"expected_hit":probe[3],"passed":passed})
	var output = FileAccess.open(OS.get_environment("CAPTURE_ARTIFACT_DIR") + "/workshop-service-bay-clearance.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(results,"  "))
	print("WORKSHOP_SERVICE_BAY ","FAIL" if failed else "PASS"," routes=6 collision_probes=4")
	quit(1 if failed else 0)
