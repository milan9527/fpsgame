extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	for frame in range(3):
		await physics_frame
	var results := []
	var passed := true
	# These rays query the complete scene, so an obsolete flat collider
	# masking a ditch is detected even if the new terrain mesh is correct.
	for along in [49.2, 85.0]:
		for side in [-1.0, 1.0]:
			var origin := Vector3(side * 7.8, 2.0, along)
			var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0, 5, 0))
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			var ok := false
			var height = null
			var collider := ""
			if not hit.is_empty():
				height = hit.position.y
				collider = str(hit.collider.get_path())
				ok = absf(height) < 0.08 if along == 49.2 else height < -0.1 and height > -0.8
			passed = passed and ok
			results.append({"origin": str(origin), "height": height, "collider": collider, "passed": ok})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("excavation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "results": results}, "\t"))
	file.close()
	print("ROAD_EXCAVATION_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
