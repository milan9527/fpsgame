extends SceneTree

# Resource geometry inventory, not a visibility or GPU timing measurement.
var entries := []

func _initialize() -> void:
	call_deferred("run")

func inspect(node: Node) -> void:
	var mesh: Mesh
	var instances := 1
	if node is MeshInstance3D:
		mesh = node.mesh
	elif node is MultiMeshInstance3D and node.multimesh:
		mesh = node.multimesh.mesh
		instances = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
	if mesh != null:
		var primitives := 0
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
			primitives += int((indices if indices > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3)
		entries.append({"path": str(node.get_path()), "triangles_per_instance": primitives,
			"instances": instances, "triangles": primitives * instances,
			"visible_in_tree": node.is_visible_in_tree(), "mesh": mesh.resource_path})
	for child in node.get_children():
		inspect(child)

func run() -> void:
	var cached_scene := OS.get_environment("GEOMETRY_SCENE")
	if not cached_scene.is_empty():
		var world: Node3D = load(cached_scene).instantiate()
		root.add_child(world)
		inspect(world)
		write_inventory()
		world.free()
		quit()
		return
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	inspect(game)
	write_inventory()
	quit()

func write_inventory() -> void:
	entries.sort_custom(func(a, b): return a.triangles > b.triangles)
	var file := FileAccess.open(OS.get_environment("GEOMETRY_INVENTORY"), FileAccess.WRITE)
	assert(file != null, "Cannot write geometry inventory")
	file.store_string(JSON.stringify({"scope": "Instantiated resource geometry; excludes frustum, LOD and occlusion decisions.", "meshes": entries}, "\t"))
	file.close()
	print("SCENE_GEOMETRY_INVENTORY_PASS ", entries.size())
