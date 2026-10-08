extends SceneTree

# Inspect the shipped ground cache without regenerating or changing its assets.
# Run with --path client --script ../tests/mobile_ground_inventory.gd.
# MOBILE_INVENTORY_WORLD=1 also measures the complete desktop-generated world
# before/after the mobile profile. This is not an Android asset/runtime sample.
func _initialize() -> void:
	call_deferred("run")

func inventory(world: Node3D) -> Array:
	var groups := {}
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var instances := 1
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var material: Material = node.material_override
			if material == null and node is MeshInstance3D:
				material = node.get_surface_override_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			var key := "default"
			if material is ShaderMaterial:
				key = material.shader.resource_path if material.shader != null else "empty_shader"
				if key.is_empty():
					key = "embedded_shader:%s" % material.shader.code.hash()
			elif material != null:
				key = material.get_class() + ":" + material.resource_name
			if not groups.has(key):
				groups[key] = {"material": key, "surfaces": 0, "instances": 0,
					"vertices": 0, "example": str(node.get_path())}
			groups[key].surfaces += 1
			groups[key].instances += instances
			var arrays := mesh.surface_get_arrays(surface)
			if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null:
				groups[key].vertices += arrays[Mesh.ARRAY_VERTEX].size() * instances
	var rows: Array = groups.values()
	rows.sort_custom(func(a, b): return a.surfaces > b.surfaces)
	return rows

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var full_world := OS.get_environment("MOBILE_INVENTORY_WORLD") == "1"
	var world: Node3D
	if full_world:
		world = load("res://scripts/world.gd").new()
	else:
		world = load("res://assets/android_ground.scn").instantiate()
	root.add_child(world)
	if full_world and not world.construction_complete:
		await world.construction_finished
	var before := inventory(world)
	var profile = load("res://scripts/mobile_performance.gd")
	var changes: Dictionary = profile.configure_world(world)
	var result := {"scope": "cached ground inventory; not visible draws or FPS",
		"before": before, "after": inventory(world), "changes": changes}
	if full_world:
		result.scope = "desktop-generated full world with mobile profile; not Android visible draws or FPS"
	var output := OS.get_environment("MOBILE_INVENTORY_OUTPUT")
	if output.is_empty():
		printerr("MOBILE_INVENTORY_OUTPUT is required")
		quit(2)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null, "Cannot write inventory")
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("MOBILE_GROUND_INVENTORY_COMPLETE ", JSON.stringify(changes))
	world.free()
	quit()
