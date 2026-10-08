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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world_visuals.gd")
	var snapshots: Array = []
	var keep_alive: Array[GDScript] = []
	for optimized in [false, true]:
		var script := GDScript.new()
		script.source_code = source.replace('OS.has_feature("android")', 'true')
		if not optimized:
			var start := script.source_code.find("static func drainage_pipe_mesh()")
			var end := script.source_code.find("static func drainage_material_yards(", start)
			var block := script.source_code.substr(start, end - start)
			script.source_code = script.source_code.substr(0, start) + block.replace(
				"\t\tsurface.optimize_indices_for_cache()\n", "") + script.source_code.substr(end)
		assert(script.reload() == OK)
		keep_alive.append(script)
		snapshots.append(script.drainage_pipe_mesh().surface_get_arrays(0))
	var before: Array = snapshots[0]
	var after: Array = snapshots[1]
	for slot in range(Mesh.ARRAY_MAX):
		if slot != Mesh.ARRAY_INDEX:
			assert(before[slot] == after[slot], "Vertex attributes changed")
	assert(triangles(before[Mesh.ARRAY_INDEX]) == triangles(after[Mesh.ARRAY_INDEX]), "Oriented triangle multiset changed")
	var report := {
		"vertices": before[Mesh.ARRAY_VERTEX].size(),
		"triangles": before[Mesh.ARRAY_INDEX].size() / 3,
		"attributes_and_oriented_triangles_exact": true,
		"scope": "LRU vertex reuse model only; not measured GPU cache misses or Android FPS."
	}
	for capacity in [16, 32]:
		var old := misses(before[Mesh.ARRAY_INDEX], capacity)
		var new := misses(after[Mesh.ARRAY_INDEX], capacity)
		assert(new <= old, "Vertex cache model regressed")
		if capacity == 16:
			assert(new < old, "Small vertex cache model did not improve")
		report[str(capacity)] = {"before": old, "after": new}
	print("ANDROID_PIPE_INDEX_CACHE_PASS ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		RenderingServer.render_loop_enabled = false
		root.size = Vector2i(480, 320)
		var scene := Node3D.new()
		root.add_child(scene)
		var instance := MeshInstance3D.new()
		scene.add_child(instance)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/precast_concrete.gdshader")
		material.set_shader_parameter("concrete_texture", load("res://assets/realism/concrete_albedo.jpg"))
		instance.material_override = material
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -25, 0)
		scene.add_child(light)
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.current = true
		var output := OS.get_environment("PIPE_REVIEW_DIR")
		assert(not output.is_empty())
		var meshes: Array[ArrayMesh] = []
		for arrays in snapshots:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshes.append(mesh)
		var center := meshes[0].get_aabb().get_center()
		for offset in [Vector3(0, 3, 6), Vector3(3, 1, 4)]:
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
			var label := "overview" if offset.y > 2 else "near"
			images[0].save_png(output.path_join(label + "-before.png"))
			images[1].save_png(output.path_join(label + "-after.png"))
			print("PIPE_GL_REVIEW ", label, " differences=", differences, " foreground=", foreground)
			assert(foreground > 100)
			assert(differences == 0)
		print("PIPE_GL_REVIEW_PASS")
	quit()
