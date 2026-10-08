extends SceneTree

func misses(indices: PackedInt32Array, capacity: int) -> int:
	var cache: Array[int] = []
	var count := 0
	for index in indices:
		if cache.has(index):
			cache.erase(index)
		else:
			count += 1
		cache.push_front(index)
		if cache.size() > capacity:
			cache.pop_back()
	return count

func triangles(indices: PackedInt32Array) -> Dictionary:
	var result := {}
	for i in range(0, indices.size(), 3):
		var key := Vector3i(indices[i], indices[i + 1], indices[i + 2])
		result[key] = result.get(key, 0) + 1
	return result

func vertex_block_switches(indices: PackedInt32Array) -> int:
	var previous := -1
	var switches := 0
	for index in indices:
		var block_id: int = index / 16
		if block_id != previous:
			switches += 1
			previous = block_id
	return switches

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var start := source.find("\tvar surface := SurfaceTool.new()", source.find("static func repair_service_access("))
	var end := source.find("\tvar access := MeshInstance3D.new()", start)
	assert(start >= 0 and end > start)
	# Execute the production mesh construction without creating scenery,
	# invoking collision generation, or enabling ground baking.
	source += "\nstatic func review_access_mesh() -> Array:\n" + source.substr(start, end - start) + "\treturn access_arrays\n"
	var snapshots: Array = []
	var keep_alive: Array[GDScript] = []
	for android in [false, true]:
		var script := GDScript.new()
		script.source_code = source.replace('OS.has_feature("android")', str(android))
		assert(script.reload() == OK)
		keep_alive.append(script)
		snapshots.append(script.review_access_mesh())
	var before: Array = snapshots[0]
	var after: Array = snapshots[1]
	var original_by_position := {}
	for i in before[Mesh.ARRAY_VERTEX].size():
		assert(not original_by_position.has(before[Mesh.ARRAY_VERTEX][i]))
		original_by_position[before[Mesh.ARRAY_VERTEX][i]] = i
	var inverse := PackedInt32Array()
	for position in after[Mesh.ARRAY_VERTEX]:
		assert(original_by_position.has(position))
		inverse.append(original_by_position[position])
	assert(inverse.size() == original_by_position.size())
	for slot in range(Mesh.ARRAY_MAX):
		if slot == Mesh.ARRAY_INDEX or before[slot] == null:
			continue
		assert(before[slot].size() == after[slot].size())
		var stride: int = before[slot].size() / inverse.size()
		for vertex in inverse.size():
			for component in stride:
				assert(before[slot][inverse[vertex] * stride + component] == after[slot][vertex * stride + component], "Vertex attributes changed")
	var restored := PackedInt32Array()
	var seen := {}
	for index in after[Mesh.ARRAY_INDEX]:
		restored.append(inverse[index])
		if not seen.has(index):
			assert(index == seen.size(), "Vertices are not stored in first-use order")
			seen[index] = true
	assert(triangles(before[Mesh.ARRAY_INDEX]) == triangles(restored), "Oriented triangle multiset changed")
	var old_switches := vertex_block_switches(restored)
	var new_switches := vertex_block_switches(after[Mesh.ARRAY_INDEX])
	assert(new_switches < old_switches)
	var report := {
		"vertices": before[Mesh.ARRAY_VERTEX].size(),
		"triangles": before[Mesh.ARRAY_INDEX].size() / 3,
		"attributes_and_oriented_triangles_exact": true,
		"vertex_fetch_first_use_order": true,
		"logical_16_vertex_block_switches_same_triangle_order": {"before": old_switches, "after": new_switches},
		"scope": "LRU vertex reuse model only; not measured GPU cache misses or Android FPS."
	}
	for capacity in [16, 32]:
		var old := misses(before[Mesh.ARRAY_INDEX], capacity)
		var new := misses(after[Mesh.ARRAY_INDEX], capacity)
		assert(new < old)
		report[str(capacity)] = {"before": old, "after": new}
	print("ANDROID_ACCESS_INDEX_CACHE_PASS ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
		root.size = Vector2i(480, 320)
		var scene := Node3D.new()
		root.add_child(scene)
		var instance := MeshInstance3D.new()
		scene.add_child(instance)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/service_access.gdshader")
		material.set_shader_parameter("noise_lattice", load("res://assets/realism/ground_noise.png"))
		material.set_shader_parameter("aggregate", load("res://assets/realism/terrain_rock_albedo.jpg"))
		keep_alive[1].configure_service_path(material)
		instance.material_override = material
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		scene.add_child(light)
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.current = true
		var output := OS.get_environment("ACCESS_REVIEW_DIR")
		assert(not output.is_empty())
		var meshes: Array[ArrayMesh] = []
		for arrays in snapshots:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshes.append(mesh)
		var center := meshes[0].get_aabb().get_center()
		for offset in [Vector3(0, 38, 18), Vector3(10, 4, 5)]:
			camera.position = center + offset
			camera.look_at(center)
			var images: Array[Image] = []
			for mesh in meshes:
				instance.mesh = mesh
				await process_frame
				RenderingServer.force_draw(false)
				RenderingServer.force_draw(false)
				images.append(root.get_texture().get_image())
			var differences := 0
			var foreground := 0
			var background := images[0].get_pixel(0, 0)
			for y in range(images[0].get_height()):
				for x in range(images[0].get_width()):
					if images[0].get_pixel(x, y) != background:
						foreground += 1
					if images[0].get_pixel(x, y) != images[1].get_pixel(x, y):
						differences += 1
			var label := "overview" if offset.y > 10 else "near"
			images[0].save_png(output.path_join(label + "-before.png"))
			images[1].save_png(output.path_join(label + "-after.png"))
			print("ACCESS_GL_REVIEW ", label, " differences=", differences, " foreground=", foreground)
			assert(foreground > 100)
			assert(differences == 0)
		print("ACCESS_GL_REVIEW_PASS")
	quit()
