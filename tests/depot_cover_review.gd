extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var space = world.get_world_3d().direct_space_state
	var results := []
	for z in [30.3, 32.5]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			Vector3(23, 0.75, z), Vector3(26, 0.75, z), 1))
		assert(not hit.is_empty() and absf(hit.position.x - 24.05) < 0.01, "Crate side collision mismatch")
		results.append({"crate_z": z, "side_hit": str(hit.position)})
	var braces := 0
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh is BoxMesh or not mesh.mesh.size.is_equal_approx(Vector3(0.09, 0.8, 0.09)):
			continue
		if mesh.global_position.distance_to(Vector3(24.5, 2.78, 34)) > 7:
			continue
		var sample: Vector3 = mesh.to_global(Vector3(0, 0.2, 0))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(
			sample + Vector3(0, 0, 0.3), sample - Vector3(0, 0, 0.3), 1))
		assert(not hit.is_empty() and absf(hit.position.z - sample.z - 0.045) < 0.005, "Rotated brace collision mismatch")
		braces += 1
	assert(braces == 6)
	var crate = load("res://assets/realism/supply_crate.glb").instantiate()
	root.add_child(crate)
	var bounds := AABB()
	var first := true
	for mesh in crate.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	assert(bounds.size.distance_to(Vector3(2.5, 1.5, 2)) < 0.03, "Crate visible bounds mismatch")
	assert(bounds.position.distance_to(Vector3(-1.25, 0, -1)) < 0.03, "Crate visible origin mismatch")
	print("DEPOT_COVER_PASS rotated_braces=", braces, " visible_crate_bounds=", bounds, " hits=", JSON.stringify(results))
	quit()
