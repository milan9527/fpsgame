extends SceneTree

const Visuals = preload("res://scripts/world_visuals.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	RenderingServer.render_loop_enabled = false
	root.size = Vector2i(960, 600)
	var world := Node3D.new()
	root.add_child(world)
	Visuals.service_road_drainage(world)
	var evidence := {"fragments": [], "baked_surfaces": [], "other_transforms": [], "collision_faces": []}
	for node in world.find_children("*", "Node3D", true, false):
		if node is MeshInstance3D and node.mesh is SphereMesh:
			evidence.fragments.append([str(node.transform), str(node.material_override.albedo_color)])
		elif node is MeshInstance3D and node.name.begins_with("DrainageGravel"):
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var surface := {"vertices": [], "normals": [], "colors": []}
			for v in arrays[Mesh.ARRAY_VERTEX]:
				surface.vertices.append([v.x, v.y, v.z])
			for n in arrays[Mesh.ARRAY_NORMAL]:
				surface.normals.append([n.x, n.y, n.z])
			for c in arrays[Mesh.ARRAY_COLOR]:
				surface.colors.append([c.r, c.g, c.b, c.a])
			evidence.baked_surfaces.append(surface)
		else:
			evidence.other_transforms.append(str(node.transform))
			if node is CollisionShape3D and node.shape is ConcavePolygonShape3D:
				evidence.collision_faces.append(str(node.shape.get_faces()))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.32, 0.36, 0.40)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.82, 0.94)
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45, -35, 0)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(7.3, 1.4, 31.5)
	camera.look_at(Vector3(8.9, 0.1, 30))
	camera.current = true
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var unit := SphereMesh.new()
	unit.radius = 1.0
	unit.height = 2.0
	unit.radial_segments = 5
	unit.rings = 2
	evidence["unit_vertices"] = []
	evidence["unit_normals"] = []
	for v in unit.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		evidence.unit_vertices.append([v.x, v.y, v.z])
	for n in unit.get_mesh_arrays()[Mesh.ARRAY_NORMAL]:
		evidence.unit_normals.append([n.x, n.y, n.z])
	for i in range(8):
		await process_frame
		RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(output.path_join("drainage.png")) == OK)
	var file := FileAccess.open(output.path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence))
	print("DRAINAGE_CAPTURE individual_fragments=", evidence.fragments.size(),
		" baked_surfaces=", evidence.baked_surfaces.size(),
		" collision_shapes=", evidence.collision_faces.size())
	quit()
