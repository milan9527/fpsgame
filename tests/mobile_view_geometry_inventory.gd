extends SceneTree

# Source geometry candidates, not GPU timing or imported mesh LOD selection.
var Mobile: GDScript
var diagnostic_scripts: Array[GDScript] = []
var triangle_cache := {}

func android_branch_script(path: String) -> GDScript:
	# In-memory only: select production Android branches, including baked assets.
	# Keep resources alive so preloads resolve to these scripts during this run.
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace('OS.has_feature("android")', "true")
	# Preserve every base triangle; test generated distant LODs on baked facade
	# batches without changing production resources or mesh import settings.
	if path == "res://scripts/mobile_performance.gd" and OS.get_environment("VIEW_GEOMETRY_FACADE_LOD") == "1":
		var marker := "\t\t\tcombined.mesh = surface.commit()"
		assert(script.source_code.count(marker) == 1)
		script.source_code = script.source_code.replace(marker, marker + """
			var lod_importer := ImporterMesh.new()
			lod_importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, combined.mesh.surface_get_arrays(0))
			lod_importer.generate_lods(60.0, 0.0, [])
			combined.mesh = lod_importer.get_mesh()""")
	var dense_cell := OS.get_environment("VIEW_GEOMETRY_DENSE_CELL")
	if path == "res://scripts/mobile_performance.gd" and not dense_cell.is_empty():
		assert(dense_cell.is_valid_float() and dense_cell.to_float() >= 2.0)
		var marker := "if dense_meshes[node.mesh]:\n\t\t\t\tcell_size = 8.0"
		assert(script.source_code.contains(marker))
		script.source_code = script.source_code.replace(marker,
			"if dense_meshes[node.mesh]:\n\t\t\t\tcell_size = " + str(dense_cell.to_float()))
	# Diagnostic-only cell sizing: keep all tufts and production assets intact.
	var grass_cell := OS.get_environment("VIEW_GEOMETRY_STATIC_GRASS_CELL")
	if path == "res://scripts/world_visuals.gd" and not grass_cell.is_empty():
		assert(grass_cell.is_valid_float() and grass_cell.to_float() >= 2.0)
		var start := script.source_code.find("static func batch_static_grass(")
		var end := script.source_code.find("\nstatic func ", start + 1)
		assert(start >= 0 and end > start)
		var original := script.source_code.substr(start, end - start)
		var replacement := original.replace("12.0", str(grass_cell.to_float())).replace("+ 6.0", "+ " + str(grass_cell.to_float() * 0.5))
		script.source_code = script.source_code.substr(0, start) + replacement + script.source_code.substr(end)
	if path == "res://scripts/world_visuals.gd":
		for stage in ["batch_static_grass(world)", 'batch_facade(world, "wall_lamp", "lamp_placements")']:
			var marker: String = "\t" + stage + "\n"
			script.source_code = script.source_code.replace(marker,
				"\tworld.set_meta(\"population_before_" + stage.get_slice("(", 0) + "\", world.get_tree().grass_population(world))\n"
				+ marker
				+ "\tworld.set_meta(\"population_after_" + stage.get_slice("(", 0) + "\", world.get_tree().grass_population(world))\n")
	script.take_over_path(path)
	assert(script.reload() == OK)
	diagnostic_scripts.append(script)
	return script

func _initialize() -> void:
	call_deferred("run")

func triangles(mesh: Mesh) -> int:
	var id := mesh.get_instance_id()
	if triangle_cache.has(id):
		return triangle_cache[id]
	var count := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		count += int((indices.size() if indices != null and indices.size() > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3)
	triangle_cache[id] = count
	return count

func intersects_frustum(bounds: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		var all_outside := true
		for corner in range(8):
			if not plane.is_point_over(bounds.get_endpoint(corner)):
				all_outside = false
				break
		if all_outside:
			return false
	return true

func static_grass_census(world: Node3D) -> Dictionary:
	# Cell changes also change mobile per-batch thinning and distance culling.
	# Compare the entire population, including cells outside this camera.
	var transforms: Array[String] = []
	var batches := 0
	for node: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := node.multimesh
		if mm == null or mm.mesh == null:
			continue
		var material: Material = node.material_override
		if material == null and mm.mesh.get_surface_count() > 0:
			material = mm.mesh.surface_get_material(0)
		if not material is ShaderMaterial or material.shader == null:
			continue
		if not ("leaf_normal" in material.shader.code and "sky_normal" in material.shader.code):
			continue
		batches += 1
		var active := mm.instance_count if mm.visible_instance_count < 0 else mini(mm.instance_count, mm.visible_instance_count)
		for i in range(active):
			var transform := node.global_transform * mm.get_instance_transform(i)
			# Ignore tiny float differences from rebasing at a different cell.
			var components := PackedStringArray()
			for vector in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
				components.append("%.3f,%.3f,%.3f" % [vector.x, vector.y, vector.z])
			transforms.append(mm.mesh.resource_path + ":" + ";".join(components))
	transforms.sort()
	return {"batches": batches, "active_instances": transforms.size(),
		"world_transform_sha256_rounded_1mm": "\n".join(transforms).sha256_text()}

func grass_population(world: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for node: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := node.multimesh
		if mm == null or mm.mesh == null:
			continue
		var material: Material = node.material_override
		if material == null and mm.mesh.get_surface_count() > 0:
			material = mm.mesh.surface_get_material(0)
		if not material is ShaderMaterial or material.shader == null:
			continue
		var code: String = material.shader.code
		var animated: bool = node.get_meta("mobile_grass", false) or ("tuft_variation" in code and "colony_hash" in code)
		var static_grass := "leaf_normal" in code and "sky_normal" in code
		if not animated and not static_grass:
			continue
		rows.append({"instance_id": node.get_instance_id(), "path": str(node.get_path()), "kind": "animated" if animated else "static",
			"allocated": mm.instance_count, "visible_instance_count": mm.visible_instance_count,
			"active": mm.instance_count if mm.visible_instance_count < 0 else mini(mm.instance_count, mm.visible_instance_count)})
	return rows

func run() -> void:
	RenderingServer.render_loop_enabled = false
	var android_assets := OS.get_environment("VIEW_GEOMETRY_ANDROID_ASSETS") == "1"
	# Compare offline terrain candidates without replacing the production
	# resource or invoking the ground baker. Keep this resource alive until exit.
	var terrain_candidate: PackedScene
	var terrain_path := OS.get_environment("VIEW_GEOMETRY_TERRAIN_CHUNKS")
	if not terrain_path.is_empty():
		assert(android_assets)
		terrain_candidate = load(terrain_path) as PackedScene
		assert(terrain_candidate != null)
		terrain_candidate.take_over_path("res://assets/android_terrain_chunks.scn")
	var world_script: GDScript
	if android_assets:
		android_branch_script("res://scripts/world_visuals.gd")
		world_script = android_branch_script("res://scripts/world.gd")
	else:
		world_script = load("res://scripts/world.gd")
	var mobile_override := OS.get_environment("MOBILE_PERFORMANCE_SCRIPT")
	Mobile = load(mobile_override if not mobile_override.is_empty() else "res://scripts/mobile_performance.gd")
	if mobile_override.is_empty() and not OS.get_environment("VIEW_GEOMETRY_DENSE_CELL").is_empty():
		Mobile = android_branch_script("res://scripts/mobile_performance.gd")
	if android_assets:
		# Apply Android viewport settings before materials inspect MSAA.
		Mobile.configure_window(root)
	var world: Node3D = world_script.new()
	root.add_child(world)
	if not world.construction_complete:
		await world.construction_finished
	print("VIEW_GEOMETRY_STAGE construction_complete")
	var yard_cache := OS.get_environment("VIEW_GEOMETRY_YARD_MESH")
	if not yard_cache.is_empty():
		assert(OS.get_environment("VIEW_GEOMETRY_YARD_LOD") != "1")
		var yard := world.find_child("ServiceYardGround", true, false) as MeshInstance3D
		assert(yard != null)
		yard.mesh = load(yard_cache) as ArrayMesh
		assert(yard.mesh != null)
	# In-memory experiment only: retain the authored yard surface and add
	# optional index LODs without changing cached terrain or collision assets.
	if OS.get_environment("VIEW_GEOMETRY_YARD_LOD") == "1":
		var yard := world.find_child("ServiceYardGround", true, false) as MeshInstance3D
		assert(yard != null and yard.mesh is ArrayMesh)
		var lod_builder = load("res://scripts/terrain_mesh_lod.gd")
		yard.mesh = lod_builder.build(yard.mesh)
	var grass_before_mobile := static_grass_census(world)
	var population_before := grass_population(world)
	var missing_probe: Array[Dictionary] = []
	var present := {}
	for row in population_before: present[row.instance_id] = true
	for row in world.get_meta("population_after_batch_facade", []):
		if present.has(row.instance_id): continue
		var node := instance_from_id(row.instance_id) as MultiMeshInstance3D
		missing_probe.append({"path": row.path, "exists": node != null,
			"allocated": node.multimesh.instance_count if node != null else -1,
			"material_class": node.material_override.get_class() if node != null and node.material_override != null else "none",
			"found_by_children": node in world.get_children() if node != null else false})
	var configured: Dictionary = Mobile.configure_world(world)
	var grass_after_mobile := static_grass_census(world)
	var population_after := grass_population(world)
	print("VIEW_GEOMETRY_STAGE configured")
	root.size = Vector2i(1440, 900)
	# A smaller diagnostic viewport bounds software-rasterizer cost without
	# changing the camera aspect or the source-geometry/frustum inventory.
	if OS.get_environment("VIEW_GEOMETRY_SMALL_VIEWPORT") == "1":
		root.size = Vector2i(480, 300)
	var camera := Camera3D.new()
	# Preserve old inventory comparisons unless explicitly matching player FOV.
	var requested_fov := OS.get_environment("VIEW_GEOMETRY_FOV")
	if not requested_fov.is_empty():
		camera.fov = float(requested_fov)
		assert(camera.fov > 0.0 and camera.fov < 180.0)
	root.add_child(camera)
	camera.position = Vector3(2, 1.6, 61)
	var target := Vector3(0, 3.2, -85)
	# Repeatable full-scene viewpoints for spatial batching comparisons.
	# This changes only the diagnostic camera, never resource visibility.
	match OS.get_environment("VIEW_GEOMETRY_VIEW"):
		"road_left":
			target = Vector3(-60, 3.2, -25)
		"road_right":
			target = Vector3(60, 3.2, -25)
		"road_forward":
			camera.position = Vector3(2, 1.6, 21)
			target = Vector3(0, 3.2, -85)
		"spawn":
			camera.position = Vector3(17, 1.65, 50)
			target = Vector3(-1, 2.2, 66)
		"yard":
			camera.position = Vector3(19, 1.65, 48)
			target = Vector3(17, 0, 40)
		"crossing":
			camera.position = Vector3(7, 5, 8)
			target = Vector3.ZERO
		"distant":
			camera.position = Vector3(0, 80, 250)
			target = Vector3.ZERO
	# Replay a recorded Android stall without approximating its viewing angle.
	# Same keys as ANDROID_RENDER_STALL; ignored timing/counter fields allow
	# passing the complete sample. Never change scene content for this replay.
	var recorded_pose := OS.get_environment("VIEW_GEOMETRY_CAMERA_JSON")
	if not recorded_pose.is_empty():
		var pose = JSON.parse_string(recorded_pose)
		assert(pose is Dictionary, "VIEW_GEOMETRY_CAMERA_JSON must be a JSON object.")
		# Match recorded projection and resolution policy. A small replay
		# retains aspect ratio; software-renderer timing is never acceptance.
		if pose.has("viewport_size"):
			var size = pose.viewport_size
			assert(size is Array and size.size() == 2)
			for component in size:
				assert((component is float or component is int) and is_finite(float(component)) and component >= 1.0 and component <= 16384.0)
			var replay_size := Vector2(float(size[0]), float(size[1]))
			if OS.get_environment("VIEW_GEOMETRY_SMALL_VIEWPORT") == "1":
				replay_size *= minf(1.0, 480.0 / maxf(replay_size.x, replay_size.y))
			root.size = Vector2i(maxi(1, roundi(replay_size.x)), maxi(1, roundi(replay_size.y)))
		if pose.has("scale"):
			assert((pose.scale is float or pose.scale is int) and is_finite(float(pose.scale)) and pose.scale > 0.0 and pose.scale <= 2.0)
			root.scaling_3d_scale = float(pose.scale)
		# Explicit FOV overrides permit controlled comparisons; otherwise use
		# the recorded value, including zoomed aim views.
		if requested_fov.is_empty() and pose.has("camera_fov"):
			camera.fov = float(pose.camera_fov)
			assert(is_finite(camera.fov) and camera.fov > 0.0 and camera.fov < 180.0)
		for key in ["camera_position", "camera_forward"]:
			assert(pose.get(key) is Array and pose[key].size() == 3, "Camera vectors require three numbers.")
			for component in pose[key]:
				assert((component is float or component is int) and is_finite(float(component)), "Camera components must be finite numbers.")
		camera.position = Vector3(pose.camera_position[0], pose.camera_position[1], pose.camera_position[2])
		var forward := Vector3(pose.camera_forward[0], pose.camera_forward[1], pose.camera_forward[2])
		assert(forward.length_squared() > 0.000001, "Camera forward must be nonzero.")
		assert(forward.normalized().cross(Vector3.UP).length_squared() > 0.000001, "Camera forward requires a nonvertical direction.")
		target = camera.position + forward.normalized()
	camera.look_at(target)
	camera.current = true
	var controller: Node
	var grass_root_scan_inventory: Array[Dictionary] = []
	if android_assets:
		controller = Mobile.new()
		controller.register_distance_nodes(world)
		# Inspect the production entries after batching and mobile policy.
		# Synthetic grouping benchmarks alone cannot establish scene coverage.
		for entry in controller.distance_nodes:
			if entry.grass_root_points.is_empty():
				continue
			var grouped_roots := 0
			var largest_group := 0
			for group in entry.grass_root_groups:
				grouped_roots += group.size()
				largest_group = maxi(largest_group, group.size())
			assert(grouped_roots == 0 or grouped_roots == entry.grass_root_points.size())
			grass_root_scan_inventory.append({
				"path": str(entry.node.get_path()),
				"roots": entry.grass_root_points.size(),
				"groups": entry.grass_root_groups.size(),
				"grouped_roots": grouped_roots,
				"largest_group": largest_group,
			})
		while true:
			controller.update_distance_visibility(camera.position, Time.get_ticks_usec())
			if controller.cull_cursor == 0:
				break
	var rendered := {}
	var warmup_coverage: Array[Dictionary] = []
	if OS.get_environment("VIEW_GEOMETRY_WARMUP_COVERAGE") == "1":
		assert(android_assets and controller != null)
		assert(DisplayServer.get_name() != "headless", "Warmup coverage requires OpenGL/Xvfb.")
		# Follow the production warmup, including its distance-scan settling.
		# Frustum eligibility cannot prove unoccluded draws or GPU compilation.
		var probes: Array[GeometryInstance3D] = []
		var replay_probes := OS.get_environment("VIEW_GEOMETRY_WARMUP_REPLAY_PROBES") == "1"
		var replay_planes := camera.get_frustum()
		for node in world.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh
			if node is MeshInstance3D:
				mesh = node.mesh
			elif node is MultiMeshInstance3D and node.multimesh != null:
				mesh = node.multimesh.mesh
			else:
				continue
			var selected: bool = node.name == "Terrain_0_5_5"
			# Select the settled gameplay frustum before warm_world moves the
			# camera. These are conservative candidates, not unoccluded draws.
			var replay_eligible: bool = mesh != null and node.is_visible_in_tree() and intersects_frustum(
				node.global_transform * node.get_aabb(), replay_planes)
			if node is MultiMeshInstance3D:
				replay_eligible = replay_eligible and node.multimesh.instance_count > 0 and node.multimesh.visible_instance_count != 0
			selected = selected or (replay_probes and replay_eligible)
			var shaders: Array[String] = []
			if mesh != null:
				for surface in range(mesh.get_surface_count()):
					var material: Material = node.material_override
					if material == null:
						material = node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
					if material is ShaderMaterial and material.shader != null:
						var shader_path: String = material.shader.resource_path
						if shader_path not in shaders:
							shaders.append(shader_path)
						selected = selected or shader_path.ends_with("/workbench_wood.gdshader") or shader_path.ends_with("/workshop_pegboard.gdshader")
			if selected:
				probes.append(node)
				warmup_coverage.append({"path": str(node.get_path()), "node_class": node.get_class(),
					"shaders": shaders, "replay_eligible": replay_eligible, "eligible_frames": 0, "views": []})
		assert(not probes.is_empty(), "Expected terrain/workbench probes.")
		var replay_transform := camera.transform
		var observe := func():
			# warm_world also draws the restored gameplay pose; it is not
			# evidence that the loading-screen views covered this resource.
			if camera.transform.is_equal_approx(replay_transform):
				return
			var planes := camera.get_frustum()
			for index in range(probes.size()):
				var node := probes[index]
				if node is MultiMeshInstance3D and (node.multimesh.instance_count == 0 or node.multimesh.visible_instance_count == 0):
					continue
				var bounds: AABB = node.global_transform * node.get_aabb()
				if not node.is_visible_in_tree() or not intersects_frustum(bounds, planes):
					continue
				warmup_coverage[index].eligible_frames += 1
				var view := {"position": [camera.position.x, camera.position.y, camera.position.z],
					"yaw": camera.rotation.y, "fov": camera.fov}
				if view not in warmup_coverage[index].views:
					warmup_coverage[index].views.append(view)
		RenderingServer.frame_post_draw.connect(observe)
		RenderingServer.render_loop_enabled = true
		await Mobile.warm_world(camera, controller)
		RenderingServer.render_loop_enabled = false
		RenderingServer.frame_post_draw.disconnect(observe)
		print("VIEW_GEOMETRY_WARMUP_COVERAGE probes=", warmup_coverage.size())
	if OS.get_environment("VIEW_GEOMETRY_RENDER") == "1":
		assert(DisplayServer.get_name() != "headless", "Rendered inventory requires OpenGL/Xvfb.")
		# Android simulation uses the settled production distance scan above,
		# including grass root distances and partitioned batch metadata bounds.
		# Flush scene registration and draw the complete scene; source counts
		# below remain separate because they do not account for imported LODs.
		for frame in range(4):
			await process_frame
			print("VIEW_GEOMETRY_STAGE draw_begin ", frame)
			RenderingServer.force_draw(false)
			print("VIEW_GEOMETRY_STAGE draw_end ", frame)
		rendered = {
			"view": OS.get_environment("VIEW_GEOMETRY_VIEW"),
			"camera_position": [camera.position.x, camera.position.y, camera.position.z],
			"camera_target": [target.x, target.y, target.z],
			"device": RenderingServer.get_video_adapter_name(),
			"method": RenderingServer.get_current_rendering_method(),
			"viewport": [root.size.x, root.size.y],
			"mesh_lod_threshold": root.mesh_lod_threshold,
			"yard_lod_experiment": OS.get_environment("VIEW_GEOMETRY_YARD_LOD") == "1",
			"camera_fov": camera.fov,
			"scaling_3d_scale": root.scaling_3d_scale,
			"draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"scope": "Complete scene desktop renderer counters, not Android FPS or acceptance."
		}
		assert(rendered.draw_calls > 0 and rendered.primitives > 0)
		# Optional real-render capture for checking batching/culling candidates.
		# Never writes imported scene assets or invokes a resource baker.
		var capture_path := OS.get_environment("VIEW_GEOMETRY_CAPTURE")
		if not capture_path.is_empty():
			assert(root.get_texture().get_image().save_png(capture_path) == OK)
	var rows := []
	var frustum := camera.get_frustum()
	for node in world.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D:
			mesh = node.mesh
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count if node.multimesh.visible_instance_count < 0 else node.multimesh.visible_instance_count
		if mesh == null or not node.is_visible_in_tree():
			continue
		var local_bounds: AABB = node.get_aabb()
		if node is MultiMeshInstance3D:
			# Derive populated bounds from real transforms. The dummy renderer's
			# MultiMesh AABB can be empty; do not silently omit entire batches.
			if instances == 0:
				continue
			local_bounds = node.multimesh.get_instance_transform(0) * mesh.get_aabb()
			for instance in range(1, instances):
				local_bounds = local_bounds.merge(
					node.multimesh.get_instance_transform(instance) * mesh.get_aabb())
			if node.multimesh.custom_aabb.size != Vector3.ZERO:
				local_bounds = node.multimesh.custom_aabb
		if node.custom_aabb.size != Vector3.ZERO:
			local_bounds = node.custom_aabb
		var bounds: AABB = node.global_transform * local_bounds
		var distance_bounds: AABB = node.get_meta("mobile_distance_bounds", bounds)
		var distance := distance_bounds.get_center().distance_to(camera.position)
		var end: float = node.visibility_range_end
		if controller == null and end == 0.0 and not node.get_meta("mobile_background_grove", false):
			end = Mobile.detail_distance(distance_bounds.size.length())
		if distance < node.visibility_range_begin or (end > 0.0 and distance >= end):
			continue
		if not intersects_frustum(bounds, frustum):
			continue
		var frustum_instances := instances
		if node is MultiMeshInstance3D:
			frustum_instances = 0
			for instance in range(instances):
				var instance_bounds: AABB = (node.global_transform *
					node.multimesh.get_instance_transform(instance)) * mesh.get_aabb()
				if intersects_frustum(instance_bounds, frustum):
					frustum_instances += 1
		# MultiMesh is culled as a batch. Individual bounds explain wasted
		# vertex work; they must never replace the full submitted source count.
		var surface_materials := []
		for surface in range(mesh.get_surface_count()):
			var effective: Material = node.material_override
			if effective == null and node is MeshInstance3D:
				effective = node.get_surface_override_material(surface)
			if effective == null:
				effective = mesh.surface_get_material(surface)
			surface_materials.append({
				"class": effective.get_class() if effective != null else "",
				"shader": effective.shader.resource_path if effective is ShaderMaterial and effective.shader != null else "",
				"surface_override": node is MeshInstance3D and node.get_surface_override_material(surface) != null,
			})
		rows.append({"instance_id": node.get_instance_id(), "path": str(node.get_path()), "kind": node.get_class(),
			"surface_materials": surface_materials,
			"mesh": mesh.resource_path, "instances": instances,
			"mesh_class": mesh.get_class(), "world_center": str(bounds.get_center()),
			"material": str(node.material_override.resource_path) if node.material_override != null else "",
			"triangles": triangles(mesh) * instances, "surfaces": mesh.get_surface_count(),
			"frustum_instances": frustum_instances,
			"frustum_instance_triangles": triangles(mesh) * frustum_instances,
			"outside_frustum_instance_triangles": triangles(mesh) * (instances - frustum_instances),
			"distance": distance, "diameter": bounds.size.length(), "range_end": end})
	rows.sort_custom(func(a, b): return a.triangles > b.triangles)
	var output := OS.get_environment("VIEW_GEOMETRY_OUTPUT")
	assert(not output.is_empty())
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"scope": "Source geometry with mobile policy; conservative road frustum and distance candidates; excludes occlusion and mesh LOD, not Android GPU measurements.",
		"android_asset_branches": android_assets,
		"yard_cached_mesh": yard_cache,
		"dense_cell_override": OS.get_environment("VIEW_GEOMETRY_DENSE_CELL"),
		"static_grass_before_mobile": grass_before_mobile,
		"static_grass_after_mobile": grass_after_mobile,
		"grass_population_before_mobile": population_before,
		"missing_population_probe": missing_probe,
		"grass_population_after_mobile": population_after,
		"grass_root_scan_inventory": grass_root_scan_inventory,
		"population_before_static_batch": world.get_meta("population_before_batch_static_grass", []),
		"population_after_static_batch": world.get_meta("population_after_batch_static_grass", []),
		"population_after_facade_batch": world.get_meta("population_after_batch_facade", []),
		"viewport": [root.size.x, root.size.y],
		"rendered": rendered,
		"warmup_coverage": warmup_coverage,
		"configured": configured, "meshes": rows}, "\t"))
	file.close()
	print("MOBILE_VIEW_GEOMETRY_INVENTORY_PASS ", rows.size())
	if controller != null:
		controller.free()
	world.queue_free()
	camera.queue_free()
	await process_frame
	quit()
