extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var world = load("res://scripts/world.gd").new()
	var items := {}
	for id in range(120):
		items[id] = {"p": Vector3(id, 0, 0), "kind": id % 6}
		if id % 2:
			items[id]["drop_slot"] = 0
	world.show_loot(items)
	var geometries := {}
	var materials := {}
	for id in items:
		var proxy: MeshInstance3D = world.loot_nodes[id]
		geometries[proxy.mesh.get_instance_id()] = true
		materials[proxy.material_override.get_instance_id()] = true
	assert(geometries.size() == 2)
	assert(materials.size() == 120, "Highlight materials must stay independent")
	var full_mesh = world.loot_nodes[0].mesh
	var compact_mesh = world.loot_nodes[1].mesh
	items[0]["drop_slot"] = 0
	world.show_loot(items)
	assert(world.loot_nodes[0].mesh == compact_mesh)
	assert(world.loot_nodes[2].mesh == full_mesh)
	assert(full_mesh.size == Vector3(0.65, 0.5, 0.65))
	assert(compact_mesh.size == Vector3(0.65, 0.2, 0.65))
	assert(world.loot_nodes[0].get_node("SupplyCaseVisual").scale == compact_mesh.size)
	world.highlight_supply(0)
	assert(world.loot_nodes[0].material_override.emission_enabled)
	assert(not world.loot_nodes[1].material_override.emission_enabled)
	items[0].erase("drop_slot")
	world.show_loot(items)
	assert(world.loot_nodes[0].mesh == full_mesh)
	world.free()
	await process_frame
	print("LOOT_SHARED_GEOMETRY_PASS 120 drops 2 meshes independent highlight and resize")
	quit()
