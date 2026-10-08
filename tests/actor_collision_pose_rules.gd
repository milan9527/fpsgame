extends SceneTree

class ObservedShape extends CollisionShape3D:
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await physics_frame
	var original: CollisionShape3D = actor.body_shape
	var observed := ObservedShape.new()
	observed.shape = original.shape
	observed.transform = original.transform
	actor.remove_child(original)
	original.queue_free()
	actor.add_child(observed)
	actor.body_shape = observed
	observed.set_notify_local_transform(true)
	# Standing clearance must keep the same orientation and center at every
	# lean angle, including nonzero world positions and yaw across a full turn.
	actor.global_position = Vector3(12, 3, -9)
	# Target points must agree with the pivoted pose through neutral lean,
	# including tiny nonzero lean values (which must not snap to upright).
	for lowered in [false, true]:
		actor.set_stance(lowered)
		for yaw_step in range(-8, 9):
			actor.yaw = yaw_step * PI / 4
			for amount in [-1.0, -0.001, 0.0, 0.001, 1.0]:
				actor.lean = amount
				var basis := Basis(Vector3.UP, actor.yaw)
				var expected_lean_basis := basis * Basis(Vector3.BACK, -amount * actor.LEAN_ANGLE)
				assert(actor.lean_basis().is_equal_approx(expected_lean_basis))
				var expected_eye: Vector3 = actor.position + basis * actor.lean_point(
					Vector3.UP * actor.eye_height())
				var expected_aim: Vector3 = actor.position + basis * actor.lean_point(
					Vector3.UP * (0.72 if lowered else 1.1))
				var expected_base: Vector3 = actor.position + basis * actor.lean_point(Vector3.ZERO)
				assert(actor.eye_position().is_equal_approx(expected_eye))
				assert(actor.aim_position().is_equal_approx(expected_aim))
				assert(actor.hit_base().is_equal_approx(expected_base))
				assert(actor.is_headshot(actor.eye_position()))
				# Compare hit classification with the former full inverse pose,
				# including the exact upright threshold and nearby body/head hits.
				for height_offset in [-0.1, -0.00001, 0.0, 0.00001, 0.1]:
					for lateral in [-2.0, 0.0, 2.0]:
						var point: Vector3 = actor.position + Vector3(
							lateral, actor.headshot_height() + height_offset, -lateral)
						var expected_head: bool = (expected_lean_basis.inverse() * (
							point - expected_base)).y > actor.headshot_height()
						assert(actor.is_headshot(point) == expected_head)
	actor.set_stance(false)
	for yaw_step in range(-4, 5):
		actor.yaw = yaw_step * PI / 4
		for lean_step in range(-10, 11):
			actor.lean = lean_step / 10.0
			actor.can_stand()
			var expected := Transform3D(actor.lean_basis(),
				actor.global_position + Basis(Vector3.UP, actor.yaw)
				* actor.lean_point(Vector3.UP * (actor.STANDING_HEIGHT / 2))
				+ Vector3.UP * 0.015)
			assert(actor.standing_query.transform.is_equal_approx(expected),
				"Standing clearance query must preserve its collision transform")
	# Exercise the actual angular sweep at translated positions, both stances
	# and a full turn of yaw. The final probe must track the pivoted capsule.
	actor.grounded = true
	actor.sprint = false
	for lowered in [false, true]:
		actor.set_stance(lowered)
		for yaw_step in range(-4, 5):
			actor.yaw = yaw_step * PI / 4
			for direction in [-1.0, 1.0]:
				actor.lean = -direction
				actor.lean_input = direction
				actor.update_lean(0.4)
				assert(is_equal_approx(actor.lean, direction),
					"Unobstructed sweep must reach the requested lean")
				var expected := Transform3D(actor.lean_basis(),
					actor.position + Basis(Vector3.UP, actor.yaw)
					* actor.lean_point(Vector3.UP * observed.shape.height / 2))
				assert(actor.lean_query.transform.is_equal_approx(expected),
					"Lean sweep must preserve the pivoted collision transform")
	actor.yaw = 0
	actor.global_position = Vector3.ZERO
	# Fallback visuals keep their other scale axes and repair external edits.
	var animation_available: bool = actor.character_animation.available
	actor.character_animation.available = false
	for lowered in [true, false]:
		actor.body_mesh.scale = Vector3(1.2, 0.5, 0.8)
		actor.set_stance(lowered)
		var expected_scale := Vector3(1.2,
			actor.CROUCH_HEIGHT / actor.STANDING_HEIGHT if lowered else 1.0, 0.8)
		assert(actor.body_mesh.scale.is_equal_approx(expected_scale))
		for tick in range(120):
			actor.set_stance(lowered)
		assert(actor.body_mesh.scale.is_equal_approx(expected_scale))
	actor.character_animation.available = animation_available
	actor.body_mesh.scale = Vector3.ONE
	# A moving lean should submit its center and roll together. Compare with
	# the original independent setters, including external rotation/scale.
	var reference := Node3D.new()
	root.add_child(reference)
	for order in range(6):
		observed.rotation_order = order
		observed.rotation = Vector3(0.13, -0.09, 0.0)
		observed.scale = Vector3(1.1, 0.9, 1.2)
		reference.rotation_order = order
		reference.transform = observed.transform
		actor.lean = 0.42
		reference.position = actor.lean_point(Vector3.UP * observed.shape.height / 2)
		reference.rotation.z = -actor.lean * actor.LEAN_ANGLE
		observed.changes = 0
		actor.apply_lean_pose()
		assert(observed.transform.is_equal_approx(reference.transform),
			"Combined pose must preserve rotation order and external scale")
		assert(observed.changes == 1,
			"Changing lean must submit a single collision transform")
	observed.rotation_order = EULER_ORDER_YXZ
	observed.rotation = Vector3.ZERO
	observed.scale = Vector3.ONE
	reference.queue_free()
	# Compare against the independent point helper across both stance ranges.
	for lowered in [false, true]:
		actor.set_stance(lowered)
		for step in range(-100, 101):
			actor.lean = float(step) / 100.0
			actor.apply_lean_pose()
			assert(observed.position.is_equal_approx(
				actor.lean_point(Vector3.UP * observed.shape.height / 2)))
			assert(actor.body_mesh.position.is_equal_approx(actor.lean_point(Vector3.ZERO)))
			assert(actor.head.position.is_equal_approx(
				actor.lean_point(Vector3.UP * actor.eye_height())))
	actor.lean = 0.65
	actor.set_stance(true)
	var leaning_pose := observed.transform
	observed.changes = 0
	for i in range(120):
		actor.set_stance(true)
		actor.apply_lean_pose()
	assert(observed.changes == 0, "Stable leaning crouch must not rewrite collision transforms")
	actor.set_stance(false)
	assert(observed.changes > 0 and observed.transform != leaning_pose,
		"Standing must immediately change the collision pose")
	actor.lean = -0.65
	actor.apply_lean_pose()
	assert(observed.position.x < 0, "Opposite lean must update collision position")
	# External pose changes must still be corrected; no stale cached pose.
	observed.position = Vector3.ZERO
	actor.apply_lean_pose()
	assert(observed.position != Vector3.ZERO, "Pose refresh must repair external changes")
	actor.apply_damage(10000)
	var dead_pose := observed.transform
	actor.lean = 0
	actor.apply_lean_pose()
	assert(observed.transform == dead_pose, "Dead pose remains unchanged")
	print("ACTOR_COLLISION_POSE_PASS stable_notifications=0 moving_notifications=1 rotation_orders=6 stance=ok lean=ok repair=ok dead=ok")
	actor.queue_free()
	await process_frame
	quit()
