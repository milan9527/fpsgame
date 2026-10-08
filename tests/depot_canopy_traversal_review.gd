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
	var visuals = load("res://scripts/world_visuals.gd")
	# A plant origin outside the slab can still put its rotated crown inside.
	var plant := Node3D.new()
	root.add_child(plant)
	plant.position = Vector3(20.8, 0, 34)
	plant.rotation.y = 0.6
	var crown := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2, 1, 2)
	crown.mesh = mesh
	crown.position.x = 1
	plant.add_child(crown)
	var slab := Rect2(21.7, 28.4, 5.6, 11.2)
	var overlap: bool = visuals.growth_overlaps_rect(plant, slab)
	plant.position.x = 15
	var separated: bool = not visuals.growth_overlaps_rect(plant, slab)
	plant.free()
	var removed: int = world.get_meta("depot_removed_growth", 0)
	var clearance_pass := overlap and separated and removed > 0
	failed = failed or not clearance_pass
	results.append({"offset_rotated_crown_detected": overlap, "outside_crown_preserved": separated, "loading_slab_plants_removed": removed, "passed": clearance_pass})
	for route_x in [22.8, 23.4]:
		for direction in [-1.0, 1.0]:
			actor.position = Vector3(route_x, 0.3, 34 - direction * 7)
			actor.velocity = Vector3.ZERO
			actor.yaw = 0
			actor.move_input = Vector2.ZERO
			for frame in range(30):
				await physics_frame
				actor.move_step(1.0 / 60.0)
			var start: Vector3 = actor.position
			actor.move_input = Vector2(0, direction)
			for frame in range(360):
				await physics_frame
				actor.move_step(1.0 / 60.0)
				if (actor.position.z - 34) * direction > 6.8:
					break
			var passed: bool = (actor.position.z - 34) * direction > 6.8
			failed = failed or not passed
			results.append({"route_x": route_x, "direction": direction, "start": str(start), "end": str(actor.position), "passed": passed})
	actor.position = Vector3(23.2, 0.3, 31.45)
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector2.ZERO
	for frame in range(30):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	actor.move_input = Vector2(-1, 0)
	for frame in range(100):
		await physics_frame
		actor.move_step(1.0 / 60.0)
	var stopped: bool = actor.position.x > 22.1 and actor.position.x < 22.8
	failed = failed or not stopped
	results.append({"windbreak_capsule_stop": str(actor.position), "passed": stopped})
	actor.move_input = Vector2.ZERO
	var space = world.get_world_3d().direct_space_state
	# Sample a leaf bay away from its new central structural mullion.
	for sample in [Vector2(1.61, 30.19), Vector2(1.7425, 30.19), Vector2(1.7425, 31.45)]:
		var height: float = sample.x
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(21.5, height, sample.y), Vector3(22.5, height, sample.y), 1))
		var expect_hit: bool = height < 1.7 or sample.y > 31.0
		var passed: bool = not hit.is_empty() if expect_hit else hit.is_empty()
		failed = failed or not passed
		results.append({"slat_ray_height": height, "ray_z": sample.y, "expect_hit": expect_hit, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("depot-canopy-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("DEPOT_CANOPY_TRAVERSAL_", "FAIL" if failed else "PASS", " ", JSON.stringify(results))
	quit(1 if failed else 0)
