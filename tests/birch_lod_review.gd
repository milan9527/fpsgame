extends SceneTree
## Render authored, previous mobile and current mobile birches under one camera.
## BIRCH_BEFORE must point to a preserved GLB from before regeneration.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	root.size = Vector2i(1500, 700)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.57, 0.68, 0.77)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.86, 1.0)
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.2
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	camera.position = Vector3(0, 4, 24)
	camera.look_at(Vector3(0, 4, 0))
	camera.current = true
	var paths := ["res://assets/realism/verge_birch.glb",
		OS.get_environment("BIRCH_BEFORE"),
		"res://assets/realism/verge_birch_mobile.glb"]
	for i in range(paths.size()):
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(paths[i], state)
		if error != OK:
			push_error("Cannot read birch: " + paths[i])
			quit(1)
			return
		var tree := document.generate_scene(state)
		scene.add_child(tree)
		tree.position.x = (i - 1) * 6.5
		var triangles := 0
		for mesh in tree.find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		print("BIRCH_REVIEW ", i, " triangles=", triangles)
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("BIRCH_REVIEW_OUTPUT")
	if output.is_empty():
		output = "/tmp/birch-lod-review.png"
	var error := root.get_texture().get_image().save_png(output)
	print("BIRCH_REVIEW_SAVED ", output, " error=", error)
	quit(error)
