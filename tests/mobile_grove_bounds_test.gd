extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var profile = load("res://scripts/mobile_performance.gd")
	var world := Node3D.new()
	root.add_child(world)
	var grove := MultiMeshInstance3D.new()
	grove.name = "BackgroundGroves"
	var quad := QuadMesh.new()
	quad.size = Vector2(9.5, 9.5)
	var material := StandardMaterial3D.new()
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	grove.material_override = material
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.use_colors = true
	original.mesh = quad
	original.instance_count = 3
	var poses: Array[Transform3D] = []
	for i in range(3):
		var pose := Transform3D(Basis.from_scale(Vector3(0.3 + i * 0.3, 0.9, 0.3 + i * 0.3)),
			Vector3(i * 150.0, 4.0, 140.0))
		poses.append(pose)
		original.set_instance_transform(i, pose)
		original.set_instance_color(i, Color(0.2 + i * 0.2, 0.5, 0.4))
	grove.multimesh = original
	world.add_child(grove)
	assert(profile.split_background_groves(world) == 3)
	var instances := 0
	for batch in world.get_children():
		if batch == grove:
			continue
		var pose: Transform3D = batch.multimesh.get_instance_transform(0)
		var index := roundi(pose.origin.x / 150.0)
		assert(pose == poses[index])
		assert(batch.multimesh.get_instance_color(0).is_equal_approx(original.get_instance_color(index)))
		var bounds: AABB = batch.custom_aabb
		assert(bounds == batch.multimesh.custom_aabb)
		var old_radius: float = profile._background_grove_radius(quad, pose, false)
		assert(bounds.size.x < old_radius * 2.0)
		# Independently construct all shader-rotated corners over a full turn.
		for angle in range(360):
			var yaw := Basis(Vector3.UP, deg_to_rad(float(angle)))
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					var corner := pose.origin + yaw * Vector3(x * 4.75 * pose.basis.x.length(),
						y * 4.75 * pose.basis.y.length(), 0.0)
					assert(bounds.grow(0.0001).has_point(corner))
		instances += batch.multimesh.instance_count
	assert(instances == original.instance_count)
	assert(profile.split_background_groves(world) == 0)
	world.free()
	print("Grove bounds: preserved transforms/colors/count, 4320 rotated corners enclosed, tighter cells, idempotent")
	quit()
