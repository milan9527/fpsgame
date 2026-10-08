extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	actor.position = Vector3(12, 3, -9)
	actor.set_stance(true)
	var ceiling := StaticBody3D.new()
	ceiling.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.2, 4)
	shape.shape = box
	ceiling.add_child(shape)
	root.add_child(ceiling)
	ceiling.position = actor.position + Vector3.UP * 1.65
	await physics_frame
	await physics_frame
	for blocked in [true, false, true]:
		ceiling.position.y = actor.position.y + (1.65 if blocked else 5.0)
		await physics_frame
		await physics_frame
		for yaw_step in range(-8, 9):
			actor.yaw = yaw_step * PI / 4
			for amount in [-1.0, -0.001, 0.0, 0.001, 1.0]:
				actor.lean = amount
				var actual: bool = actor.can_stand()
				var reference := PhysicsShapeQueryParameters3D.new()
				reference.shape = actor.standing_probe
				reference.collision_mask = 7
				reference.exclude = [actor.get_rid()]
				reference.transform = Transform3D(actor.lean_basis(),
					actor.global_position + Basis(Vector3.UP, actor.yaw)
					* actor.lean_point(Vector3.UP * (actor.STANDING_HEIGHT / 2))
					+ Vector3.UP * 0.015)
				var expected: bool = actor.get_world_3d().direct_space_state.intersect_shape(
					reference, 1).is_empty()
				assert(actual == expected, "Standing probe must preserve real collision results")
				if amount == 0.0:
					assert(actual == not blocked, "Moving ceiling must update standing clearance")
	print("PASS standing clearance: 255 yaw/lean/moving-ceiling checks")
	quit()
