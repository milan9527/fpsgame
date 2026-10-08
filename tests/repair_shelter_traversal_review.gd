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
		["moved_tree_blocks_player", Vector3(26.8, 0.3, 46.6), Vector2(0, -1), 40, 45.0, 45.4],
		["moved_tree_side_passage", Vector3(27.8, 0.3, 46.6), Vector2(0, -1), 40, 42.5, 44.0],
		["front_to_rear", Vector3(15.5, 0.3, 38), Vector2(0, -1), 150, 23.0, 26.0],
		["rear_to_front", Vector3(15.5, 0.3, 24), Vector2(0, 1), 150, 36.0, 39.0],
		["boards_block_player", Vector3(13.4, 0.3, 32.5), Vector2(0, -1), 60, 31.3, 32.2],
		["grove_side_passage", Vector3(20.0, 0.3, 42), Vector2(0, -1), 100, 32.0, 35.0],
		["road_beside_new_grove", Vector3(8.5, 0.3, 27), Vector2(0, -1), 150, 12.0, 15.0]]:
		actor.position = route[1]
		actor.velocity = Vector3.ZERO
		actor.yaw = 0
		actor.move_input = Vector2.ZERO
		for frame in range(20):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		actor.move_input = route[2]
		for frame in range(route[3]):
			await physics_frame
			actor.move_step(1.0 / 60.0)
		var passed: bool = actor.position.z > route[4] and actor.position.z < route[5]
		failed = failed or not passed
		results.append({"route": route[0], "start": str(route[1]), "end": str(actor.position), "passed": passed})
	# The new work surface stops a vertical shot and cannot intrude on the aisle.
	for bench_x in [15.5, 18.0]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(bench_x, 1.8, 29.4), Vector3(bench_x, 0.6, 29.4), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = hit.is_empty() if bench_x == 15.5 else not hit.is_empty() and absf(hit.position.y - 0.975) < 0.02
		failed = failed or not passed
		results.append({"workbench_x": bench_x, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for ray in [[1.5, 28.0, 24.0], [3.5, 28.0, 24.0], [3.5, 24.0, 28.0]]:
		var height: float = ray[0]
		var query := PhysicsRayQueryParameters3D.create(Vector3(15.5, height, ray[1]), Vector3(15.5, height, ray[2]), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = hit.is_empty() if height < 2 else not hit.is_empty() and absf(hit.position.z - 26.08) < 0.1
		failed = failed or not passed
		results.append({"ray_height": height, "from_z": ray[1], "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for ends in [[32.0, 34.0], [34.0, 32.0]]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(15.5, 4.0, ends[0]), Vector3(15.5, 4.0, ends[1]), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = not hit.is_empty() and absf(hit.position.z - 32.98) < 0.03
		failed = failed or not passed
		results.append({"front_clerestory_from_z": ends[0], "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for x in [12.9, 15.5, 18.1]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 1.4, 34), Vector3(x, 1.4, 32.5), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = hit.is_empty() if x == 15.5 else not hit.is_empty() and absf(hit.position.z - 33.18) < 0.05
		failed = failed or not passed
		results.append({"front_door_x": x, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	# x/z locate the trunk; y is its expected physical radius in metres.
	# Crown height and width now vary independently along the service road.
	for tree in [Vector3(22.4, 0.133, 42.25), Vector3(24.7, 0.0588, 44),
		Vector3(26.8, 0.161, 44.6), Vector3(28.4, 0.0812, 41.6),
		Vector3(10.2, 0.091392, 24.1), Vector3(11.8, 0.193536, 17.8), Vector3(13, 0.213248, 11.9)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(tree.x - 0.5, 0.5, tree.z), Vector3(tree.x + 0.5, 0.5, tree.z), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = not hit.is_empty() and absf(hit.position.x - (tree.x - tree.y)) < 0.03
		failed = failed or not passed
		results.append({"sapling": str(tree), "expected_radius": tree.y, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	for x in [12.24, 15.5, 18.76]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 1.4, 36), Vector3(x, 1.4, 34.5), 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		var passed: bool = hit.is_empty() if x == 15.5 else not hit.is_empty() and absf(hit.position.z - 35.18) < 0.03
		failed = failed or not passed
		results.append({"porch_post_x": x, "hit": str(hit.get("position", Vector3.ZERO)), "passed": passed})
	var roof_ray := PhysicsRayQueryParameters3D.create(Vector3(15.5, 4, 34.2), Vector3(15.5, 2.7, 34.2), 1)
	var roof_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(roof_ray)
	var roof_pass: bool = not roof_hit.is_empty() and absf(roof_hit.position.y - 3.262) < 0.03
	failed = failed or not roof_pass
	results.append({"pitched_porch_roof": str(roof_hit.get("position", Vector3.ZERO)), "passed": roof_pass})
	# Actual transformed mesh bounds must remain outside the loading roof.
	var roof_bounds := AABB(Vector3(21.7, 3.19, 28.5), Vector3(5.6, 0.12, 11))
	var trees_checked := 0
	for child in world.get_children():
		if not child.has_meta("repair_yard_sapling"):
			continue
		trees_checked += 1
		for mesh in child.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			var clear: bool = not bounds.intersects(roof_bounds)
			failed = failed or not clear
			results.append({"tree_roof_clearance": str(child.position), "mesh_bounds": str(bounds), "passed": clear})
	failed = failed or trees_checked != 4
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("repair-shelter-traversal.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"results": results, "passed": not failed}, "\t"))
	file.close()
	print("REPAIR_SHELTER_TRAVERSAL_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
