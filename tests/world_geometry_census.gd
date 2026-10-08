extends SceneTree

# Counts source geometry, not GPU submissions: frustum, occlusion and imported
# mesh LOD selection are deliberately not estimated. Distance ranges are applied
# to ordinary instances; MultiMesh instance counts are reported as a batch.
var groups := {}
var triangle_cache := {}
var camera_position := Vector3(0, 1.6, 68)

func _initialize() -> void:
	call_deferred("run")

func triangles(mesh: Mesh) -> int:
	var id := mesh.get_instance_id()
	if triangle_cache.has(id):
		return triangle_cache[id]
	var count := 0
	for surface in range(mesh.get_surface_count()):
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		count += (indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	triangle_cache[id] = count
	return count

func record(node: GeometryInstance3D, mesh: Mesh, instances: int) -> void:
	if mesh == null or instances <= 0 or not node.is_visible_in_tree():
		return
	var distance := camera_position.distance_to(node.global_position)
	if node.visibility_range_begin > 0 and distance < node.visibility_range_begin:
		return
	if node.visibility_range_end > 0 and distance >= node.visibility_range_end:
		return
	var key := mesh.resource_path
	if key.is_empty():
		key = mesh.get_class() + ":" + str(node.name).rstrip("0123456789")
	if not groups.has(key):
		groups[key] = {"source": key, "nodes": 0, "instances": 0, "source_triangles": 0, "surfaces": 0, "shadow_instances": 0}
	var row: Dictionary = groups[key]
	row.nodes += 1
	row.instances += instances
	row.source_triangles += triangles(mesh) * instances
	row.surfaces += mesh.get_surface_count() * instances
	if node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		row.shadow_instances += instances

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	for node in game.world.find_children("*", "MeshInstance3D", true, false):
		record(node, node.mesh, 1)
	for node in game.world.find_children("*", "MultiMeshInstance3D", true, false):
		if node.multimesh == null:
			continue
		var count: int = node.multimesh.visible_instance_count
		if count < 0:
			count = node.multimesh.instance_count
		record(node, node.multimesh.mesh, count)
	var rows := groups.values()
	rows.sort_custom(func(a, b): return a.source_triangles > b.source_triangles)
	var output := OS.get_environment("GEOMETRY_CENSUS_OUTPUT")
	assert(not output.is_empty())
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"camera_position": [camera_position.x, camera_position.y, camera_position.z],
		"scope": "World source geometry within node distance ranges; not rendered GPU triangles",
		"groups": rows
	}, "\t") + "\n")
	file.close()
	print("WORLD_GEOMETRY_CENSUS_PASS groups=", rows.size())
	quit()
