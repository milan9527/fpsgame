extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	var original := MeshInstance3D.new()
	original.mesh = load("res://assets/android_terrain.res")
	root.add_child(original)
	var chunks_path := OS.get_environment("TERRAIN_CHUNKS_INPUT")
	if chunks_path.is_empty():
		chunks_path = "res://assets/android_terrain_chunks.scn"
	var chunks: Node3D = load(chunks_path).instantiate()
	root.add_child(chunks)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.5, 0.2)
	original.material_override = material
	for child in chunks.get_children():
		child.material_override = material
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -142, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	var results := []
	for view in [
		{"name":"spawn", "position":Vector3(17,1.65,50), "target":Vector3(-1,2.2,66)},
		{"name":"road", "position":Vector3(2,1.6,61), "target":Vector3(0,3.2,-85)},
		{"name":"yard", "position":Vector3(19,1.65,48), "target":Vector3(17,0,40)},
		{"name":"crossing", "position":Vector3(7,5,8), "target":Vector3.ZERO},
		{"name":"distant", "position":Vector3(0,80,250), "target":Vector3.ZERO}]:
		camera.position = view.position
		camera.look_at(view.target)
		var counts := {}
		for mode in ["original", "chunks"]:
			original.visible = mode == "original"
			chunks.visible = mode == "chunks"
			for frame in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			counts[mode] = {
				"primitives":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
				"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}
			assert(root.get_texture().get_image().save_png(output.path_join(view.name + "-" + mode + ".png")) == OK)
		results.append({"view":view.name, "counts":counts})
	var report := {"views":results, "scope":"isolated terrain, neutral material, desktop OpenGL; not Android FPS or final visual acceptance"}
	var file := FileAccess.open(output.path_join("render-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TERRAIN_CHUNKS_RENDER_REVIEW ", JSON.stringify(report))
	quit()
