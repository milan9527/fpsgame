extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Android vegetation baking requires a real renderer; use xvfb-run with gl_compatibility.")
		quit(1)
		return
	# Keep real renderer storage for MultiMesh serialization without drawing
	# an unused world or allocating sky reflection targets during this bake.
	root.disable_3d = true
	var holder := Node3D.new()
	root.add_child(holder)
	var visuals = load("res://scripts/world_visuals.gd")
	visuals.RIDGE_CELLS = 24
	visuals.RIDGE_HALF = 12.0
	visuals.bake_android_ground = true
	var terrain: MeshInstance3D = visuals.excavated_surface(holder, Rect2(-120, -120, 240, 240), null, true)
	var shape: Shape3D = terrain.get_child(0).get_child(0).shape
	var chunks := preload("res://scripts/terrain_mesh_chunks.gd").build(terrain.mesh)
	if ResourceSaver.save(chunks, "res://assets/android_terrain_chunks.scn") != OK:
		quit(1)
		return
	terrain.mesh = preload("res://scripts/terrain_mesh_lod.gd").build(terrain.mesh)
	if ResourceSaver.save(terrain.mesh, "res://assets/android_terrain.res") != OK:
		quit(1)
		return
	if ResourceSaver.save(shape, "res://assets/android_terrain_collision.res") != OK:
		quit(1)
		return
	print("ANDROID_TERRAIN_BAKED vertices=", terrain.mesh.surface_get_array_len(0), " collision_faces=", shape.get_faces().size() / 3)
	holder.queue_free()
	var world = load("res://scripts/world.gd").new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	if not FileAccess.file_exists("res://assets/android_ground.scn"):
		quit(1)
		return
	# Read the serialized resource again: in-memory generation alone does not
	# prove that instance transforms, colors and variation survived baking.
	var saved: PackedScene = ResourceLoader.load("res://assets/android_ground.scn", "", ResourceLoader.CACHE_MODE_IGNORE)
	var cached := saved.instantiate()
	var checked := 0
	var mobile_ground_count := 0
	for node in cached.find_children("*", "GeometryInstance3D", true, false):
		var ground_material: Material = node.material_override
		if ground_material is ShaderMaterial:
			var shader_path: String = ground_material.shader.resource_path
			if shader_path == "res://shaders/meadow_ground.gdshader":
				push_error("Desktop meadow shader retained in Android bake: " + str(node.name))
				cached.free()
				quit(1)
				return
			if shader_path == "res://shaders/meadow_ground_mobile.gdshader":
				mobile_ground_count += 1
	if mobile_ground_count == 0:
		push_error("Android bake contains no mobile meadow material")
		cached.free()
		quit(1)
		return
	for node in cached.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = node.multimesh
		var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		if mm.instance_count > 0 and mm.buffer.size() != mm.instance_count * stride:
			push_error("Android vegetation instance buffer missing: " + str(node.name))
			quit(1)
			return
		var material: Material = node.material_override
		if material is ShaderMaterial and "grass" in material.shader.resource_path:
			for index in range(mm.instance_count):
				if not mm.get_instance_color(index).is_equal_approx(Color.WHITE) or mm.get_instance_custom_data(index).g < 0.5:
					push_error("Android grass color/variation lost: " + str(node.name))
					quit(1)
					return
			checked += mm.instance_count
	cached.free()
	if checked == 0:
		push_error("Android bake contains no validated grass instances")
		quit(1)
		return
	print("ANDROID_GROUND_VERIFIED grass_instances=", checked, " mobile_ground_surfaces=", mobile_ground_count)
	world.queue_free()
	call_deferred("finish")

func finish() -> void:
	# Let bake's local resource references and queued nodes be released before
	# shutting down the renderer that owns their buffers.
	await process_frame
	await process_frame
	quit()
