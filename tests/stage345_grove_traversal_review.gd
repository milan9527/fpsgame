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
	for tree in world.find_children("ShelterShoulderTrunk*", "StaticBody3D", true, false):
		var shape: CollisionShape3D = tree.get_child(0)
		var ground: float = tree.position.y - shape.shape.height * 0.5
		for bypass in [false, true]:
			actor.position = Vector3(tree.position.x - (1.1 if bypass else 0.0), ground + 0.3, tree.position.z + 2.0)
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			actor.move_input = Vector2(0, -1)
			for frame in range(180):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if actor.position.z < tree.position.z - 1.5:
					break
			var passed: bool = actor.position.z < tree.position.z - 1.5 if bypass else actor.position.z > tree.position.z + 0.25 and actor.position.z < tree.position.z + 0.9
			results.append({"tree": str(tree.position), "bypass": bypass, "end": str(actor.position), "passed": passed})
			failed = failed or not passed
	failed = failed or results.size() != 6
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("grove-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": not failed, "routes": results}, "\t"))
	file.close()
	print("GROVE_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
