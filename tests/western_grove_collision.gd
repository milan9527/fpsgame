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
	var trunks := []
	for tree in world.get_children():
		if tree is Node3D and tree.scene_file_path in ["res://assets/realism/verge_birch.glb", "res://assets/realism/fir_full.glb"]:
			var p: Vector3 = tree.global_position
			if p.x < -13.4 and p.x > -29.5 and p.z > 12.5 and p.z < 29.5:
				trunks.append(p)
	failed = trunks.size() != 11
	for trunk in trunks:
		actor.position = trunk + Vector3(0, 0.3, 1.4)
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2(0, -1)
		for frame in range(45):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var distance: float = actor.position.z - trunk.z
		var passed: bool = distance > 0.3 and distance < 0.8
		failed = failed or not passed
		results.append({"trunk": str(trunk), "actor_end": str(actor.position), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("western-grove-collision.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"expected_trunks": 11, "actual_trunks": trunks.size(), "results": results, "passed": not failed}, "\t"))
	file.close()
	print("WESTERN_GROVE_COLLISION_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
