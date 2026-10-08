extends SceneTree

class ProfileHost extends Node:
	var world: Node3D

func distance_entries(mobile: Script, world: Node3D) -> Array:
	var host := ProfileHost.new()
	host.world = world
	var profile = mobile.new()
	host.add_child(profile)
	profile._ready()
	var entries: Array = profile.distance_nodes.duplicate()
	host.free()
	return entries

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var mobile = load("res://scripts/mobile_performance.gd")
	root.size = Vector2i(480, 300)
	var world := Node3D.new()
	root.add_child(world)
	var source := MultiMeshInstance3D.new()
	source.name = "RepairAccessEmbeddedGravel"
	source.transform = Transform3D(Basis(Vector3.UP, 0.2), Vector3(2, 0, 3))
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	source.material_override = material
	source.extra_cull_margin = 0.1
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.use_colors = true
	original.use_custom_data = true
	original.mesh = BoxMesh.new()
	var partial := OS.get_environment("GRAVEL_PARTIAL_CAPACITY") == "1"
	original.instance_count = 120 if partial else 100
	if partial:
		original.visible_instance_count = 100
	for i in range(100):
		var placement := Transform3D(Basis(Vector3.UP, i * 0.1).scaled(Vector3(0.4, 0.2, 0.6)),
			Vector3((i % 10) * 2 - 9, 0, (i / 10) * 2 - 9))
		original.set_instance_transform(i, placement)
		original.set_instance_color(i, Color(float(i) / 100, 0.6, 0.2))
		original.set_instance_custom_data(i, Color(float(i) / 128, 0, 0, 1))
	source.multimesh = original
	world.add_child(source)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4, 30, 20)
	camera.look_at(Vector3(2, 0, 3))
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var foreground := 0
	for y in range(before.get_height()):
		for x in range(before.get_width()):
			if before.get_pixel(x, y) != before.get_pixel(0, 0):
				foreground += 1
	assert(foreground > 100, "Render comparison must contain visible geometry")
	var distance_bounds: AABB = source.global_transform * source.get_aabb()
	var baseline_entries := distance_entries(mobile, world)
	assert(baseline_entries.size() == 1)
	source.multimesh = mobile.compact_gravel_instances(original)
	assert(source.multimesh != original)
	assert(source.multimesh.instance_count == 100)
	assert(source.multimesh.visible_instance_count == -1)
	assert(source.multimesh.buffer.size() == 100 * 20)
	assert(original.instance_count == (120 if partial else 100))
	assert(original.visible_instance_count == (100 if partial else -1))
	var empty: MultiMesh = original.duplicate()
	empty.visible_instance_count = 0
	var compact_empty: MultiMesh = mobile.compact_gravel_instances(empty)
	assert(compact_empty.instance_count == 0 and compact_empty.buffer.is_empty())
	var count: int = mobile.split_access_gravel(world)
	assert(count > 1 and count < 20)
	assert(source.multimesh == null)
	var split_entries := distance_entries(mobile, world)
	assert(split_entries.size() == count)
	for entry in split_entries:
		assert(entry.node != source, "Empty container must not independently cull its children")
		assert(entry.center.is_equal_approx(baseline_entries[0].center))
		assert(entry.begin_squared == baseline_entries[0].begin_squared)
		assert(entry.end_squared == baseline_entries[0].end_squared)
	var seen := {}
	for batch in source.get_children():
		assert(batch.transform == Transform3D.IDENTITY)
		assert(batch.get_meta("mobile_distance_bounds") == distance_bounds)
		assert(batch.multimesh.visible_instance_count == -1)
		assert(batch.material_override == material)
		assert(batch.extra_cull_margin == source.extra_cull_margin)
		assert(batch.multimesh.mesh == original.mesh)
		for j in range(batch.multimesh.instance_count):
			var data: Color = batch.multimesh.get_instance_custom_data(j)
			var i := roundi(data.r * 128)
			assert(i < 100)
			assert(not seen.has(i))
			seen[i] = true
			var placement: Transform3D = batch.multimesh.get_instance_transform(j)
			assert(placement.is_equal_approx(original.get_instance_transform(i)))
			assert((batch.global_transform * placement).is_equal_approx(source.global_transform * original.get_instance_transform(i)))
			assert(batch.multimesh.get_instance_color(j).is_equal_approx(original.get_instance_color(i)))
			assert(data.is_equal_approx(original.get_instance_custom_data(i)))
			var bounds: AABB = placement * original.mesh.get_aabb()
			assert(batch.custom_aabb.grow(0.0001).encloses(bounds))
	assert(seen.size() == 100)
	assert(mobile.split_access_gravel(world) == 0)
	await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	assert(before.get_data() == after.get_data(), "Spatial split changed opaque rendering")
	source.hide()
	for batch in source.get_children():
		assert(not batch.is_visible_in_tree())
	print("MOBILE_ACCESS_GRAVEL_CELLS_PASS cells=", count, " instances=", seen.size(), " pixels_identical=true distance_entries_preserved=true")
	world.queue_free()
	await process_frame
	quit()
