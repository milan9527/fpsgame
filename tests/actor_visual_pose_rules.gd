extends SceneTree

class ObservedVisual extends Node3D:
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
	var original: Node3D = actor.body_mesh
	var observed := ObservedVisual.new()
	actor.add_child(observed)
	actor.body_mesh = observed
	observed.set_notify_local_transform(true)
	var reference := Node3D.new()
	root.add_child(reference)
	var expected_changes := 2 if OS.get_cmdline_user_args().has("--baseline") else 1
	var cases := 0
	for lowered in [false, true]:
		actor.set_stance(lowered)
		for order in range(6):
			for amount in [-0.8, 0.42, 1.0]:
				observed.rotation_order = order
				observed.position = Vector3.ZERO
				observed.rotation = Vector3(0.13, -0.09, 0)
				observed.scale = Vector3(1.1, 0.9, 1.2)
				reference.rotation_order = order
				reference.transform = observed.transform
				actor.lean = amount
				reference.position = actor.lean_point(Vector3.ZERO)
				reference.rotation.z = -amount * actor.LEAN_ANGLE
				observed.changes = 0
				actor.apply_lean_pose()
				assert(observed.transform.is_equal_approx(reference.transform),
					"Visual pose must match independent setters across rotation orders")
				assert(observed.changes == expected_changes,
					"Moving visual pose notification count")
				observed.changes = 0
				for tick in range(120):
					actor.apply_lean_pose()
				assert(observed.changes == 0, "Stable visual pose must not be resubmitted")
				observed.position = Vector3(2, 3, 4)
				observed.rotation.z = 0
				actor.apply_lean_pose()
				assert(observed.transform.is_equal_approx(reference.transform),
					"External visual changes must still be repaired")
				cases += 1
	actor.alive = false
	var dead_pose := observed.transform
	observed.changes = 0
	actor.lean = 0
	actor.apply_lean_pose()
	assert(observed.transform == dead_pose and observed.changes == 0)
	actor.body_mesh = original
	print("PASS actor_visual_pose_rules cases=", cases,
		" moving_notifications=", expected_changes, " stable_notifications=0 external_repair dead")
	reference.queue_free()
	actor.queue_free()
	await process_frame
	quit()
