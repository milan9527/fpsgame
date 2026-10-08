extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var output := OS.get_environment("TANK_REVIEW_DIR")
	assert(not output.is_empty())
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(480, 320)
	var scene := Node3D.new()
	root.add_child(scene)
	var shell := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.12
	cylinder.bottom_radius = 1.12
	cylinder.height = 4.6
	cylinder.radial_segments = 64
	cylinder.rings = 0
	shell.mesh = cylinder
	shell.position = Vector3(-23, 1.72, 43)
	shell.rotation.z = PI / 2
	scene.add_child(shell)
	var meshes: Array[MeshInstance3D] = [shell]
	var originals: Array[Mesh] = [cylinder]
	var candidates: Array[Mesh] = [cylinder]
	var visuals = load("res://scripts/world_visuals.gd")
	for end in [-1.0, 1.0]:
		var head := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = 1.12
		dome.height = 2.24
		dome.radial_segments = 48
		dome.rings = 24
		head.mesh = dome
		head.position = Vector3(0, end * 2.3, 0)
		head.scale = Vector3(1, 0.24, 1)
		shell.add_child(head)
		head.create_trimesh_collision()
		var collision: ConcavePolygonShape3D = head.get_child(0).get_child(0).shape
		var original_faces := collision.get_faces()
		var exterior: ArrayMesh = visuals.tank_head_exterior(dome, end)
		var before := dome.surface_get_arrays(0)
		var after := exterior.surface_get_arrays(0)
		for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV]:
			assert(before[attribute] == after[attribute])
		# ArrayMesh packs normals/tangents; verify the packing error separately.
		for vertex in range(before[Mesh.ARRAY_NORMAL].size()):
			assert(before[Mesh.ARRAY_NORMAL][vertex].distance_to(after[Mesh.ARRAY_NORMAL][vertex]) < 0.001)
		assert(after[Mesh.ARRAY_INDEX].size() < before[Mesh.ARRAY_INDEX].size())
		head.mesh = exterior
		assert(collision.get_faces() == original_faces)
		print("TANK_HEAD end=", end, " before_tri=", before[Mesh.ARRAY_INDEX].size() / 3,
			" after_tri=", after[Mesh.ARRAY_INDEX].size() / 3, " collision_unchanged=true")
		meshes.append(head)
		originals.append(dome)
		candidates.append(exterior)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.01
	scene.add_child(camera)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/workyard_tank.gdshader")
	for mesh in meshes:
		mesh.material_override = material
	var views := [Vector3(0, 0, 6), Vector3(0, 4, 3), Vector3(0, -1, 3),
		Vector3(6, 1, 0), Vector3(-6, 1, 0), Vector3(0, 0, -6),
		Vector3(1.6, 0, 2), Vector3(0, 12, 16)]
	for index in range(views.size()):
		camera.position = shell.position + views[index]
		camera.look_at(shell.position)
		var images: Array[Image] = []
		for variant in [originals, candidates]:
			for mesh_index in range(meshes.size()):
				meshes[mesh_index].mesh = variant[mesh_index]
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_draw(false)
			images.append(root.get_texture().get_image())
		var differences := 0
		var max_error := 0.0
		var colors := {}
		for y in range(images[0].get_height()):
			for x in range(images[0].get_width()):
				var a := images[0].get_pixel(x, y)
				var b := images[1].get_pixel(x, y)
				colors[a.to_rgba32()] = true
				if a != b:
					differences += 1
					max_error = maxf(max_error, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b))))
		images[0].save_png(output.path_join("view-%d-before.png" % index))
		images[1].save_png(output.path_join("view-%d-after.png" % index))
		print("TANK_GL view=", index, " colors=", colors.size(), " differences=", differences, " max_error=", max_error)
		if colors.size() < 16 or max_error > 1.0 / 255.0 + 0.000001:
			quit(1)
			return
	print("TANK_GL_PASS (visual equivalence only; not Android timing acceptance)")
	quit()
