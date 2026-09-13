extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	world.zone_mesh.hide()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 70
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var collision := []
	for node in world.find_children("*", "CollisionShape3D", true, false):
		var shape_description := str(node.shape.size) if node.shape is BoxShape3D else str(node.shape)
		if node.shape is ConvexPolygonShape3D:
			shape_description = "convex:" + str(node.shape.points)
		collision.append({"transform": str(node.global_transform), "shape": shape_description, "layer": node.get_parent().collision_layer})
	var file := FileAccess.open(out.path_join("collision.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(collision))
	file.close()
	var views := {"overview": [Vector3(112, 72, 124), Vector3(0, 0, 0)], "street": [Vector3(17, 1.7, 50), Vector3(35, 1.9, 34)], "building": [Vector3(25, 2, 17), Vector3(35, 2, 34)]}
	for node in world.get_children():
		if node.name.begins_with("fir_near"):
			views["forest"] = [node.position + Vector3(7, 2, 12), node.position + Vector3(0, 4, 0)]
			break
	for name in views:
		camera.position = views[name][0]
		camera.look_at(views[name][1])
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("WORLD_VISUAL_CAPTURE_PASS colliders=", collision.size())
	quit()
