extends SceneTree

# Desktop topology diagnostic, explicitly applying the mobile batching policy.
# Counts candidates by distance, not GPU-visible draws or Android frame times.
const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func inventory(world: Node3D) -> Dictionary:
	var groups := {}
	var total := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree():
			continue
		var bounds: AABB = node.global_transform * node.get_aabb()
		if bounds.get_center().distance_to(Vector3(2, 1.6, 61)) > 100.0:
			continue
		var material: Material = node.material_override
		if material == null and node.mesh.get_surface_count() > 0:
			material = node.mesh.surface_get_material(0)
		var material_label := "none"
		if material is ShaderMaterial:
			material_label = material.shader.resource_path
		elif material != null:
			material_label = "%s:transparency=%s" % [material.get_class(), material.transparency]
		var key := "%s|%s" % [node.mesh.resource_path if not node.mesh.resource_path.is_empty() else node.mesh.get_class(), material_label]
		if not groups.has(key):
			groups[key] = {"count": 0, "examples": [], "nonuniform": 0, "surface_override": 0}
		groups[key].count += 1
		var scale: Vector3 = node.global_basis.get_scale().abs()
		if not is_equal_approx(scale.x, scale.y) or not is_equal_approx(scale.x, scale.z):
			groups[key].nonuniform += 1
		for surface in range(node.mesh.get_surface_count()):
			if node.get_surface_override_material(surface) != null:
				groups[key].surface_override += 1
		if groups[key].examples.size() < 3:
			groups[key].examples.append(str(node.get_path()))
		total += 1
	var rows := []
	for key in groups:
		var row: Dictionary = groups[key]
		row["resource"] = key
		rows.append(row)
	rows.sort_custom(func(a, b): return a.count > b.count)
	return {"mesh_nodes_within_100m": total, "groups": rows}

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var world: Node3D = load("res://scripts/world.gd").new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	var before := inventory(world)
	var configured := Mobile.configure_world(world)
	var report := {"scope": "desktop world with mobile policy; distance candidates, not draw calls",
		"before": before, "configured": configured, "after": inventory(world)}
	var output := OS.get_environment("SCENE_INVENTORY_PATH")
	if output.is_empty():
		output = "/tmp/mobile-scene-inventory.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SCENE_INVENTORY_COMPLETE ", output)
	quit()
