extends "res://tests/mobile_facade_cache_test.gd"

func _run() -> void:
	var output := OS.get_environment("SINGLETON_REVIEW_DIR")
	assert(not output.is_empty())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 4)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	viewport.add_child(light)
	var source := SphereMesh.new()
	source.radial_segments = 32
	source.rings = 16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.4, 0.18)
	source.material = material
	var node := MeshInstance3D.new()
	node.mesh = source
	node.visibility_range_end = 120.0
	node.rotation_degrees.y = 17.0
	world.add_child(node)
	var body := StaticBody3D.new()
	node.add_child(body)
	var original_transform := node.transform
	var baseline := SurfaceTool.new()
	baseline.create_from(source, 0)
	var baseline_mesh := baseline.commit()
	var before_arrays := baseline_mesh.surface_get_arrays(0)
	var images: Array[Image] = []
	for angle in [0, 55, 125]:
		camera.position = Vector3(sin(deg_to_rad(angle)) * 4, 0.6, cos(deg_to_rad(angle)) * 4)
		camera.look_at(Vector3.ZERO)
		await process_frame
		await RenderingServer.frame_post_draw
		images.append(viewport.get_texture().get_image())
	assert(Profile.batch_static_meshes(world) == 0)
	assert(node.mesh is ArrayMesh and node.mesh != source)
	assert(node.mesh.surface_get_material(0) == material)
	assert(node.transform == original_transform and node.get_child(0) == body)
	assert(node.visibility_range_end == 120.0 and node.mesh.get_aabb().is_equal_approx(source.get_aabb()) and node.mesh.custom_aabb == source.get_aabb())
	var after_arrays := node.mesh.surface_get_arrays(0)
	assert(_triangles(before_arrays) == _triangles(after_arrays), "Visible triangle attributes/winding changed")
	assert(after_arrays[Mesh.ARRAY_INDEX].size() < before_arrays[Mesh.ARRAY_INDEX].size())
	# Untagged imported surfaces must retain their mesh and generated LODs.
	var retained := node.mesh
	assert(Profile.batch_static_meshes(world) == 0 and node.mesh == retained)
	var views := []
	for index in range(3):
		var angle: int = [0, 55, 125][index]
		camera.position = Vector3(sin(deg_to_rad(angle)) * 4, 0.6, cos(deg_to_rad(angle)) * 4)
		camera.look_at(Vector3.ZERO)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		images[index].save_png(output.path_join("before-%d.png" % angle))
		image.save_png(output.path_join("after-%d.png" % angle))
		var before := images[index].get_data()
		var after := image.get_data()
		var maximum := 0
		var changed := 0
		for i in range(before.size()):
			var delta := absi(int(before[i]) - int(after[i]))
			maximum = maxi(maximum, delta)
			changed += int(delta > 0)
		assert(maximum <= 1, "Singleton rendering changed")
		views.append({"angle": angle, "max_byte_delta": maximum, "changed_bytes": changed})
	var report := {"views": views, "triangles_before": before_arrays[Mesh.ARRAY_INDEX].size() / 3,
		"triangles_after": after_arrays[Mesh.ARRAY_INDEX].size() / 3,
		"vertices_before": before_arrays[Mesh.ARRAY_VERTEX].size(), "vertices_after": after_arrays[Mesh.ARRAY_VERTEX].size(),
		"scope": "Synthetic singleton, OpenGL rendering; not Android FPS acceptance"}
	FileAccess.open(output.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MOBILE_SINGLETON_SURFACE_PASS ", JSON.stringify(report))
	viewport.free()
	quit()
