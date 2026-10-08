extends SceneTree

class GameHost extends Node:
	var world: Node3D

class WorldFixture extends Node3D:
	var loot_nodes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	root.disable_3d = true
	var profile = load("res://scripts/mobile_performance.gd")
	assert(profile != null)
	var world := WorldFixture.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.shadow_enabled = true
	var lamp := OmniLight3D.new()
	world.add_child(lamp)
	var grass := MultiMeshInstance3D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.use_custom_data = true
	mesh.mesh = QuadMesh.new()
	mesh.instance_count = 48
	for i in range(48):
		mesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 0.1), Vector3(i, i * 0.2, -i)))
		mesh.set_instance_color(i, Color(i / 48.0, 0.5, 0.3, 0.7))
		mesh.set_instance_custom_data(i, Color(0.1, i / 48.0, 0.3, 0.9))
	grass.multimesh = mesh
	var material := ShaderMaterial.new()
	# Packing the terrain embeds shader resources: path-based detection misses them.
	material.shader = load("res://shaders/grass.gdshader").duplicate()
	material.shader.resource_path = ""
	material.set_shader_parameter("fade_begin", 37.0)
	grass.material_override = material
	world.add_child(grass)
	var original_fade = material.get_shader_parameter("fade_begin")
	var shared_grass := MultiMeshInstance3D.new()
	shared_grass.multimesh = mesh
	shared_grass.material_override = material
	world.add_child(shared_grass)
	var distinct_grass := MultiMeshInstance3D.new()
	distinct_grass.multimesh = mesh
	distinct_grass.material_override = material.duplicate()
	world.add_child(distinct_grass)
	var collider := StaticBody3D.new()
	world.add_child(collider)
	# Cached siblings lose their readable names; shared material still identifies
	# them. Newly baked cells carry metadata, even with a different material.
	var litter_material := StandardMaterial3D.new()
	var litter_cells: Array[MultiMeshInstance3D] = []
	for i in range(4):
		var cell := MultiMeshInstance3D.new()
		cell.name = "GroundLitterCell" if i == 0 else "CachedCell%d" % i
		cell.material_override = litter_material if i < 2 else StandardMaterial3D.new()
		cell.visibility_range_end = 42.0
		if i == 2:
			cell.set_meta("mobile_ground_litter", true)
		world.add_child(cell)
		litter_cells.append(cell)
	var report: Dictionary = profile.configure_world(world)
	assert(litter_cells[0].visibility_range_end == 26.0)
	assert(litter_cells[1].visibility_range_end == 26.0)
	assert(litter_cells[2].visibility_range_end == 26.0)
	assert(litter_cells[3].visibility_range_end == 42.0)
	for cell in litter_cells:
		cell.free()
	assert(report.grass_before == 144 and report.grass_after == 9)
	assert(shared_grass.material_override == grass.material_override)
	assert(distinct_grass.material_override != grass.material_override)
	assert(grass.material_override != material)
	assert(material.get_shader_parameter("fade_begin") == original_fade)
	assert(shared_grass.material_override.get_shader_parameter("fade_end") == 24.0)
	shared_grass.free()
	distinct_grass.free()
	assert(grass.multimesh.mesh == mesh.mesh)
	for i in range(3):
		assert(grass.multimesh.get_instance_transform(i) == mesh.get_instance_transform(i * 16))
		assert(grass.multimesh.get_instance_color(i) == mesh.get_instance_color(i * 16))
		assert(grass.multimesh.get_instance_custom_data(i) == mesh.get_instance_custom_data(i * 16))
	assert(collider.get_parent() == world)
	assert(not sun.shadow_enabled and not lamp.visible)
	assert(sun.directional_shadow_max_distance == 45.0)
	assert(grass.visibility_range_end == 30.0)
	assert(grass.material_override.get_shader_parameter("fade_begin") == 16.0)
	profile.configure_window(root)
	assert(root.content_scale_size == Vector2i(1440, 900))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
	var host := GameHost.new()
	host.world = world
	root.add_child(host)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var controller = profile.new()
	host.add_child(controller)
	# Sustained heavy views reduce only the 3D buffer; isolated hitches do not.
	controller.set_process(false)
	# Compare the counting implementation against the original sorted oracle,
	# including exact thresholds and sample counts around percentile boundaries.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var choices := [1.0 / 60.0, 1.0 / 59.5, 1.0 / 59.0, 1.0 / 58.0, 1.0 / 40.0]
	for sample_count in range(1, 126):
		for trial in range(12):
			controller.reset_resolution_window()
			controller.resolution_recovery_seconds = 0.0
			root.scaling_3d_scale = 0.55
			var samples: Array[float] = []
			for sample in range(sample_count):
				var elapsed: float = choices[rng.randi_range(0, choices.size() - 1)]
				samples.append(elapsed)
				# Force exactly this sample population into one decision window.
				controller.resolution_seconds = 2.0 if sample == sample_count - 1 else 0.0
				controller.adapt_resolution(elapsed)
			samples.sort()
			var percentile := samples[mini(sample_count - 1, int(sample_count * 0.8))]
			assert((controller.resolution_recovery_seconds > 0.0) == (percentile < 1.0 / 59.5))
			assert(is_equal_approx(root.scaling_3d_scale, 0.50 if percentile > 1.0 / 58.0 else 0.55))
			root.scaling_3d_scale = 0.45
			# Check recovery credit against the same sorted oracle.
			controller.resolution_recovery_seconds = 7.0
			for sample in range(sample_count):
				controller.resolution_seconds = 2.0 if sample == sample_count - 1 else 0.0
				controller.adapt_resolution(samples[sample])
			assert(is_equal_approx(root.scaling_3d_scale, 0.50 if percentile < 1.0 / 59.5 else 0.45))
			assert(controller.resolution_sample_count == 0)
			assert(controller.resolution_slow_count == 0 and controller.resolution_fast_count == 0)
	controller.reset_resolution_window()
	controller.resolution_recovery_seconds = 0.0
	root.scaling_3d_scale = 0.65
	print("RESOLUTION_PERCENTILE_ORACLE_PASS windows=3000")
	controller.adapt_resolution(0.5)
	for i in range(100):
		controller.adapt_resolution(1.0 / 60.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.65))
	controller.reset_resolution_window()
	# Reproduce the real-device plateau: 40 FPS must trigger adaptation,
	# even though it was above the former 32 FPS cutoff.
	for i in range(81):
		controller.adapt_resolution(1.0 / 40.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.60))
	controller.reset_resolution_window()
	# The measured-target gap must not leave sustained 50 FPS uncorrected.
	for i in range(101):
		controller.adapt_resolution(1.0 / 50.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.55))
	controller.reset_resolution_window()
	# In the hysteresis band neither quality nor recovery should drift.
	for i in range(1000):
		controller.adapt_resolution(1.0 / 59.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.55))
	controller.reset_resolution_window()
	profile.baseline_running = true
	for i in range(100):
		controller.adapt_resolution(1.0 / 20.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.55))
	assert(controller.resolution_sample_count == 0)
	profile.baseline_running = false
	for i in range(500):
		controller.adapt_resolution(1.0 / 25.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.45))
	assert(root.content_scale_size == Vector2i(1440, 900))
	for i in range(120):
		controller.adapt_resolution(1.0 / 60.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.45))
	for i in range(2400):
		controller.adapt_resolution(1.0 / 60.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.65))
	assert(controller.distance_nodes.size() == 1)
	assert(grass.visibility_range_end == 0.0)
	camera.position = Vector3(200, 0, 0)
	controller._process(0.2)
	assert(not grass.visible)
	assert(collider.get_parent() == world)
	camera.position = Vector3.ZERO
	controller._process(0.2)
	assert(grass.visible)
	# A pending scan must continue even when its periodic timer has not expired.
	var saved_entries = controller.distance_nodes.duplicate()
	var pending := Node3D.new()
	world.add_child(pending)
	controller.distance_nodes.append(profile.DistanceEntry.new(pending, Vector3(200, 0, 0), 0.0, 10.0))
	controller.cull_cursor = 1
	controller.cull_seconds = 100.0
	controller._process(0.001)
	assert(not pending.visible and grass.visible)
	assert(controller.cull_cursor == 0)
	controller.distance_nodes = saved_entries.duplicate()
	pending.free()
	# Begin is inclusive, end exclusive; zero end leaves the far range open.
	var ranged := Node3D.new()
	world.add_child(ranged)
	controller.distance_nodes.clear()
	controller.distance_nodes.append(profile.DistanceEntry.new(ranged, Vector3.ZERO, 5.0, 10.0))
	for distance in [4.99, 5.0, 9.99, 10.0]:
		camera.position = Vector3(distance, 0, 0)
		controller._process(0.2)
		assert(ranged.visible == (distance >= 5.0 and distance < 10.0))
	controller.distance_nodes.clear()
	controller.distance_nodes.append(profile.DistanceEntry.new(ranged, Vector3.ZERO, 5.0, 0.0))
	camera.position = Vector3(10000, 0, 0)
	controller._process(0.2)
	assert(ranged.visible)
	controller.distance_nodes = saved_entries
	ranged.free()
	camera.position = Vector3.ZERO
	# Loot arrives after the controller registers the static world.
	var loot := MeshInstance3D.new()
	loot.mesh = BoxMesh.new()
	var case_visual := Node3D.new()
	case_visual.name = "SupplyCaseVisual"
	loot.add_child(case_visual)
	var attachment := Node3D.new()
	attachment.name = "ForegripDisplay"
	loot.add_child(attachment)
	world.add_child(loot)
	world.loot_nodes[7] = loot
	loot.position = Vector3(0, 0, -40)
	controller._process(0.2)
	assert(loot.visible and loot.layers == 1)
	assert(not case_visual.visible and not attachment.visible)
	loot.position = Vector3(0, 0, -5)
	controller._process(0.2)
	assert(loot.layers == 0 and case_visual.visible and attachment.visible)
	# A stable near state must still repair independent visual changes.
	case_visual.visible = false
	attachment.visible = false
	loot.layers = 1
	controller.update_loot_detail(Vector3.ZERO, 0.2)
	assert(loot.layers == 0 and case_visual.visible and attachment.visible)
	loot.position = Vector3(0, 0, -24)
	controller.update_loot_detail(Vector3.ZERO, 0.2)
	assert(loot.layers == 1 and not case_visual.visible and not attachment.visible)
	world.loot_nodes.erase(7)
	loot.free()
	controller._process(0.2)
	# Large drop sets must continue across frames, including when entries
	# disappear or are replaced during a pending scan.
	var drops: Array[MeshInstance3D] = []
	for i in range(150):
		var drop := MeshInstance3D.new()
		var visual := Node3D.new()
		visual.name = "SupplyCaseVisual"
		drop.add_child(visual)
		world.add_child(drop)
		world.loot_nodes[i] = drop
		drops.append(drop)
	controller.update_loot_detail(Vector3.ZERO, 0.2)
	assert(controller.loot_cull_cursor > 0 and controller.loot_cull_cursor <= 64)
	assert(not controller.loot_cull_keys.is_empty())
	# The next slice must read a replacement world dictionary.
	world.loot_nodes = world.loot_nodes.duplicate()
	world.loot_nodes.erase(148)
	drops[148].free()
	drops[149].free()
	var replacement := MeshInstance3D.new()
	var replacement_visual := Node3D.new()
	replacement_visual.name = "SupplyCaseVisual"
	replacement.add_child(replacement_visual)
	world.add_child(replacement)
	world.loot_nodes[149] = replacement
	var continuation_frames := 0
	while not controller.loot_cull_keys.is_empty() and continuation_frames < 200:
		controller.update_loot_detail(Vector3.ZERO, 0.001)
		continuation_frames += 1
	assert(controller.loot_cull_keys.is_empty())
	assert(replacement.layers == 0 and replacement_visual.visible)
	# Reset during a pending scan must discard all stale IDs in one call.
	controller.update_loot_detail(Vector3.ZERO, 0.2)
	assert(not controller.loot_cull_keys.is_empty())
	world.loot_nodes = {}
	controller.update_loot_detail(Vector3.ZERO, 0.001)
	assert(controller.loot_cull_keys.is_empty())
	assert(controller.loot_cull_cursor == 0)
	# A new drop after reset still joins the next scheduled scan.
	replacement.layers = 1
	world.loot_nodes[149] = replacement
	controller.update_loot_detail(Vector3.ZERO, 0.06)
	assert(replacement.layers == 0)
	for i in range(148):
		assert(drops[i].layers == 0)
		drops[i].free()
	replacement.free()
	world.loot_nodes.clear()
	var static_world := Node3D.new()
	root.add_child(static_world)
	static_world.position = Vector3(17, 2, 5)
	var shared_material := StandardMaterial3D.new()
	var originals: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	for i in range(3):
		var item := MeshInstance3D.new()
		item.mesh = BoxMesh.new()
		item.mesh.size = Vector3(1 + i, 1, 1)
		item.material_override = shared_material
		item.position = Vector3(i * 2, 0, 0)
		static_world.add_child(item)
		item.add_child(StaticBody3D.new())
		originals.append(item)
		transforms.append(item.transform)
	originals[2].visible = false
	assert(profile.batch_static_meshes(static_world) == 2)
	assert(originals[0].mesh == null and originals[1].mesh == null)
	assert(originals[2].mesh != null)
	assert(originals[0].get_child(0) is StaticBody3D)
	var batches := static_world.find_children("MobileFacadeBatch*", "MeshInstance3D", true, false)
	assert(batches.size() == 1)
	assert(batches[0].material_override == shared_material)
	var vertices: PackedVector3Array = batches[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices.size() == 48)
	assert(batches[0].mesh.get_aabb().position.is_equal_approx(Vector3(-0.5, -0.5, -0.5)))
	assert(batches[0].mesh.get_aabb().end.is_equal_approx(Vector3(3, 0.5, 0.5)))
	static_world.queue_free()
	var mixed_world := Node3D.new()
	root.add_child(mixed_world)
	var mixed_originals: Array[MeshInstance3D] = []
	var expected_vertices := 0
	var expected_indices := 0
	for shape in [BoxMesh.new(), SphereMesh.new(), CylinderMesh.new()]:
		var item := MeshInstance3D.new()
		item.mesh = shape
		item.material_override = shared_material
		# Keep all shapes in the same small-detail distance tier.
		item.scale = Vector3.ONE * 0.1
		item.position = Vector3(4, 4, 4)
		# The batch discards exactly coincident-corner faces and vertices
		# referenced only by them. Calculate the surviving set independently.
		var source: Array = shape.get_mesh_arrays()
		var positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var referenced := {}
		for offset in range(0, indices.size(), 3):
			var a := indices[offset]
			var b := indices[offset + 1]
			var c := indices[offset + 2]
			if positions[a] == positions[b] or positions[b] == positions[c] or positions[c] == positions[a]:
				continue
			referenced[a] = true
			referenced[b] = true
			referenced[c] = true
			expected_indices += 3
		expected_vertices += referenced.size()
		mixed_world.add_child(item)
		mixed_originals.append(item)
	var glass := MeshInstance3D.new()
	glass.mesh = BoxMesh.new()
	var transparent := StandardMaterial3D.new()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = transparent
	mixed_world.add_child(glass)
	assert(profile.batch_static_meshes(mixed_world) == 3)
	for item in mixed_originals:
		assert(item.mesh == null)
	assert(glass.mesh != null)
	var mixed_batches := mixed_world.find_children("MobileFacadeBatch*", "MeshInstance3D", true, false)
	assert(mixed_batches.size() == 1)
	assert(mixed_batches[0].material_override == shared_material)
	assert(mixed_batches[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == expected_vertices)
	assert(mixed_batches[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == expected_indices)
	mixed_world.queue_free()
	var imported_world := Node3D.new()
	root.add_child(imported_world)
	var imported_mesh := ArrayMesh.new()
	var box := BoxMesh.new()
	var arrays := box.get_mesh_arrays()
	# Use a real secondary index level so accidental surface reconstruction
	# cannot silently pass as an equivalent imported mesh.
	var lods := {10.0: PackedInt32Array([0, 1, 2])}
	imported_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	imported_mesh.surface_set_material(0, shared_material)
	for i in range(2):
		var item := MeshInstance3D.new()
		item.mesh = imported_mesh
		item.position = Vector3(4 + i, 4, 4)
		imported_world.add_child(item)
	assert(profile.batch_static_meshes(imported_world) == 2)
	var imported_batches := imported_world.find_children("MobileStaticBatch*", "MultiMeshInstance3D", true, false)
	assert(imported_batches.size() == 1)
	assert(imported_batches[0].multimesh.mesh == imported_mesh)
	assert(imported_batches[0].multimesh.instance_count == 2)
	assert(imported_batches[0].multimesh.get_instance_transform(1).origin == Vector3(5, 4, 4))
	assert(imported_world.find_children("MobileFacadeBatch*", "MeshInstance3D", true, false).is_empty())
	imported_world.queue_free()
	# Bulk buffers must retain the complete basis, including nonuniform scale
	# and reflection, under a transformed world (translation alone misses
	# row/column mistakes).
	var transformed_world := Node3D.new()
	root.add_child(transformed_world)
	transformed_world.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(20, 3, -10))
	var expected_transforms: Array[Transform3D] = []
	var expected_bounds := AABB()
	for i in range(2):
		var item := MeshInstance3D.new()
		item.mesh = imported_mesh
		item.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.3, 0.1)).scaled(
			Vector3(-1.2 if i == 0 else 1.2, 0.8, 1.4)), Vector3(4 + i, 4, 4))
		item.visibility_range_end = 180.0
		transformed_world.add_child(item)
		expected_transforms.append(item.transform)
		var bounds: AABB = item.transform * item.get_aabb()
		expected_bounds = bounds if i == 0 else expected_bounds.merge(bounds)
	assert(profile.batch_static_meshes(transformed_world) == 2)
	var transformed_batches := transformed_world.find_children("MobileStaticBatch*", "MultiMeshInstance3D", true, false)
	assert(transformed_batches.size() == 1)
	var transformed_instances: MultiMesh = transformed_batches[0].multimesh
	assert(transformed_instances.mesh == imported_mesh)
	for i in range(2):
		assert(transformed_instances.get_instance_transform(i).is_equal_approx(expected_transforms[i]))
	assert(transformed_instances.custom_aabb.is_equal_approx(expected_bounds))
	transformed_world.queue_free()
	var ranged_world := Node3D.new()
	root.add_child(ranged_world)
	for distance in [90.0, 180.0]:
		for i in range(2):
			var item := MeshInstance3D.new()
			item.mesh = imported_mesh
			item.position = Vector3(4 + i, 4, 4)
			item.visibility_range_end = distance
			ranged_world.add_child(item)
	var excluded: Array[MeshInstance3D] = []
	for kind in range(3):
		var item := MeshInstance3D.new()
		item.mesh = imported_mesh
		item.visibility_range_end = 180.0
		if kind == 0:
			item.visibility_range_begin = 20.0
		elif kind == 1:
			item.visibility_range_end_margin = 10.0
		else:
			item.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		ranged_world.add_child(item)
		excluded.append(item)
	assert(profile.batch_static_meshes(ranged_world) == 4)
	var ranged_batches := ranged_world.find_children("*", "MultiMeshInstance3D", true, false)
	assert(ranged_batches.size() == 2)
	var retained_distances: Array[float] = []
	for batch in ranged_batches:
		assert(batch.multimesh.mesh == imported_mesh)
		assert(batch.multimesh.instance_count == 2)
		assert(batch.multimesh.get_instance_transform(1).origin == Vector3(5, 4, 4))
		retained_distances.append(batch.visibility_range_end)
	retained_distances.sort()
	# Centers at x=4 and x=5 require 0.5m of conservative batch padding
	# so the outer member is not culled before its original distance.
	assert(retained_distances == [90.5, 180.5])
	for item in excluded:
		assert(item.mesh == imported_mesh)
	ranged_world.queue_free()
	print("MOBILE_PERFORMANCE_PASS density transforms colors custom-data collision viewport shadows distance-culling")
	host.queue_free()
	world.queue_free()
	quit()
