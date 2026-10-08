extends SceneTree

const Mobile = preload("res://scripts/mobile_performance.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Requires real GL: use xvfb-run with gl_compatibility")
		quit(2)
		return
	RenderingServer.render_loop_enabled = false
	var world := Node3D.new()
	root.add_child(world)
	world.rotate_y(0.3)
	var grove := MultiMeshInstance3D.new()
	grove.name = "BackgroundGroves"
	grove.position = Vector3(4, 2, 9)
	grove.material_override = StandardMaterial3D.new()
	grove.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.use_colors = true
	original.use_custom_data = true
	original.mesh = QuadMesh.new()
	original.mesh.size = Vector2(9.5, 9.5)
	original.instance_count = 12
	grove.multimesh = original
	world.add_child(grove)
	for i in range(12):
		original.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 1.7, 1)),
			Vector3(-260 + i * 51, i, -180 + i * 38)))
		original.set_instance_color(i, Color(i / 12.0, 0.4, 0.2))
		original.set_instance_custom_data(i, Color(i / 12.0, 0, 0))
	var source_transform := grove.global_transform
	var cells: int = Mobile.split_background_groves(world)
	assert(cells > 1 and cells < 12)
	var seen := {}
	for batch in world.find_children("BackgroundGroveCell*", "MultiMeshInstance3D", true, false):
		assert(batch.material_override == grove.material_override)
		assert(batch.get_meta("mobile_background_grove", false))
		assert(batch.visibility_range_end == 0)
		for j in range(batch.multimesh.instance_count):
			var index := roundi(batch.multimesh.get_instance_custom_data(j).r * 12)
			assert(not seen.has(index))
			seen[index] = true
			var placement: Transform3D = batch.multimesh.get_instance_transform(j)
			assert((batch.global_transform * placement).is_equal_approx(source_transform * original.get_instance_transform(index)))
			assert(batch.multimesh.get_instance_color(j).is_equal_approx(original.get_instance_color(index)))
			# Test rotated billboard corners against the conservative batch AABB.
			for heading in range(16):
				for x in [-1, 1]:
					for y in [-1, 1]:
						var corner: Vector3 = placement.origin + Basis(Vector3.UP, heading * TAU / 16) * Vector3(x * 4.75 * 0.8, y * 4.75 * 1.7, 0)
						assert(batch.custom_aabb.has_point(corner))
	assert(seen.size() == 12)
	assert(Mobile.split_background_groves(world) == 0)
	print("BACKGROUND_GROVE_TEST_PASS instances=12 cells=", cells, " headings=16 transforms/colors/custom_data/bounds/idempotence")
	world.free()
	quit()
