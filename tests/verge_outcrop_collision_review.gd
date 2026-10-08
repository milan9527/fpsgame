extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await physics_frame
	var rock_hit := false
	actor.position = Vector3(-13.8, 0.3, 47)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2(0, -1)
	for frame in range(600):
		await physics_frame
		actor.move_step(1.0 / 60.0)
		for index in range(actor.get_slide_collision_count()):
			var node: Node = actor.get_slide_collision(index).get_collider()
			while node != null:
				if node.scene_file_path == "res://assets/realism/boulder.glb":
					rock_hit = true
				node = node.get_parent()
	var stopped: bool = actor.position.z > 42 and actor.position.z < 46
	var passed: bool = rock_hit and stopped
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	var file := FileAccess.open(out.path_join("verge-outcrop-collision.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"actor_contacts_rock": rock_hit, "actor_stopped": stopped,
		"actor_end": str(actor.position),
		"passed": passed}, "\t"))
	file.close()
	print("VERGE_OUTCROP_COLLISION_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
