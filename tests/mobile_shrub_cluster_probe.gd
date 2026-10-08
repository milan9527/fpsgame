extends SceneTree

# Experimental distant geometry only. Never modifies source/imported resources.
func cluster(source: Mesh, cell: float) -> ArrayMesh:
	var mesh := ImporterMesh.new()
	for surface in range(source.get_surface_count()):
		var a := source.surface_get_arrays(surface)
		var positions: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
		var groups := {}
		var remap := PackedInt32Array()
		var vertices := PackedVector3Array()
		var normal_sums := PackedVector3Array()
		var texcoords := PackedVector2Array()
		var counts := PackedInt32Array()
		for i in range(positions.size()):
			# Palette coordinates must never mix between differently colored leaves.
			var key := str(Vector3i((positions[i] / cell).floor())) + ":" + str(uvs[i])
			if not groups.has(key):
				groups[key] = vertices.size()
				vertices.append(Vector3.ZERO)
				normal_sums.append(Vector3.ZERO)
				texcoords.append(uvs[i])
				counts.append(0)
			var index: int = groups[key]
			remap.append(index)
			vertices[index] += positions[i]
			normal_sums[index] += normals[i]
			counts[index] += 1
		for i in range(vertices.size()):
			vertices[i] /= counts[i]
			normal_sums[i] = normal_sums[i].normalized()
		for i in range(positions.size()):
			assert(positions[i].distance_to(vertices[remap[i]]) <= sqrt(3.0) * cell + 0.00001)
			assert(uvs[i] == texcoords[remap[i]])
		var indices := PackedInt32Array()
		var original: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		for i in range(0, original.size(), 3):
			var x := remap[original[i]]
			var y := remap[original[i + 1]]
			var z := remap[original[i + 2]]
			if x == y or y == z or x == z:
				continue
			indices.append_array(PackedInt32Array([x, y, z]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normal_sums
		arrays[Mesh.ARRAY_TEX_UV] = texcoords
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			source.surface_get_material(surface))
	# Compare against imported assets with LOD enabled, not only base triangles.
	mesh.generate_lods(60.0, 0.0, [])
	return mesh.get_mesh()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("SHRUB_CLUSTER_OUTPUT")
	assert(not output.is_empty())
	root.size = Vector2i(1440, 900)
	root.mesh_lod_threshold = 4.0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-45, -30, 0)
	var rows := []
	for asset in ["verge_shrub_palette_mobile", "verge_fine_shrub_palette_mobile"]:
		var scene: Node3D = load("res://assets/realism/" + asset + ".glb").instantiate()
		var source: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var instance := MeshInstance3D.new()
		root.add_child(instance)
		for cell in [0.0, 0.01, 0.02]:
			instance.mesh = source.mesh if cell == 0.0 else cluster(source.mesh, cell)
			var center := source.mesh.get_aabb().get_center()
			for distance in [5.0, 15.0, 30.0]:
				for angle in [0.0, 120.0, 240.0]:
					camera.position = center + Vector3(sin(deg_to_rad(angle)), 0.2, cos(deg_to_rad(angle))).normalized() * distance
					camera.look_at(center)
					for frame in range(4):
						await process_frame
					await RenderingServer.frame_post_draw
					var name := "%s-c%.2f-d%.0f-a%.0f.png" % [asset, cell, distance, angle]
					assert(root.get_texture().get_image().save_png(output.path_join(name)) == OK)
					rows.append({"asset": asset, "cell_m": cell, "distance": distance, "angle": angle,
						"image": name, "primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
						"draws": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
		instance.free()
		scene.free()
	var file := FileAccess.open(output.path_join("probe.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Experimental geometry and visual probe, not Android FPS acceptance", "rows": rows}, "\t"))
	file.close()
	print("MOBILE_SHRUB_CLUSTER_PROBE_PASS")
	quit()
