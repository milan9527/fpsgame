extends SceneTree

class ObservedActor extends "res://scripts/actor.gd":
	var changes := 0
	var movement_calls := 0

	func move_step(_dt: float, _refresh_stance: bool = true, _ground_sampler: Callable = Callable()) -> void:
		# Isolate rotation notifications from CharacterBody movement. Authority
		# timers and stance still run through the real simulate() implementation.
		movement_calls += 1

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class ObservedNode extends Node3D:
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class ObservedCamera extends Camera3D:
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := ObservedActor.new()
	root.add_child(actor)
	await physics_frame
	var eye := ObservedNode.new()
	actor.add_child(eye)
	actor.head = eye
	actor.set_notify_local_transform(true)
	eye.set_notify_local_transform(true)
	actor.yaw = 0.123456789
	actor.pitch = 0.234567891
	actor.target_position = actor.position
	actor.render_frame(0, true, false, false)
	actor.changes = 0
	eye.changes = 0
	for i in range(120):
		actor.render_frame(0, true, false, false)
	assert(actor.changes == 0 and eye.changes == 0,
		"Stable render must not dirty actor/head transforms")
	actor.fire_left = 1.0
	for i in range(120):
		actor.simulate(1.0 / 60.0)
	assert(actor.changes == 0 and eye.changes == 0,
		"Stable authority simulation must not dirty actor/head transforms")
	assert(actor.movement_calls == 120 and actor.fire_left == 0,
		"Rotation optimization must preserve movement dispatch and timers")
	actor.yaw += 0.000001
	actor.pitch += 0.000001
	actor.simulate(1.0 / 60.0)
	assert(actor.changes > 0 and eye.changes > 0,
		"Small authority turns must remain responsive")
	actor.changes = 0
	eye.changes = 0
	actor.yaw += 0.000001
	actor.pitch += 0.000001
	actor.render_frame(0, true, false, false)
	assert(actor.changes > 0 and eye.changes > 0, "Small turns must remain responsive")
	assert(is_equal_approx(actor.rotation.y, actor.yaw))
	assert(is_equal_approx(eye.rotation.x, actor.pitch))
	actor.rotation.y = -0.5
	eye.rotation.x = -0.5
	actor.render_frame(0, true, false, false)
	assert(is_equal_approx(actor.rotation.y, actor.yaw))
	assert(is_equal_approx(eye.rotation.x, actor.pitch))
	var start := actor.position
	actor.target_position = start + Vector3(10, 0, 0)
	actor.weapon_kick = 1
	actor.render_frame(0.01, true, false, false)
	assert(actor.position.is_equal_approx(start + Vector3(2, 0, 0)))
	assert(is_equal_approx(actor.gun.rotation.x, 0.92 * 0.06))
	var camera := ObservedCamera.new()
	eye.add_child(camera)
	actor.camera = camera
	camera.set_notify_local_transform(true)
	actor.recoil = 0
	actor.render_frame(0, false, true, false)
	camera.changes = 0
	for i in range(120):
		actor.render_frame(0, false, true, false)
	assert(camera.changes == 0, "Stable solo camera must not dirty its transform")
	for i in range(120):
		actor.render_frame(0, true, true, false)
	assert(camera.changes == 0, "Stable online camera must not dirty its transform")
	actor.recoil = 0.01
	actor.render_frame(0, false, true, false)
	assert(camera.changes > 0 and is_equal_approx(camera.rotation.x, 0.01),
		"Recoil must still update the camera")
	camera.position = Vector3(0.1, 0.2, 0.3)
	actor.render_frame(0, false, true, false)
	assert(camera.position == Vector3.ZERO, "Solo camera must repair external offsets")
	var camera_origin := camera.global_position
	actor.camera_error = Vector3(0.1, 0.05, 0)
	actor.render_frame(0, true, true, false)
	assert(camera.global_position.is_equal_approx(camera_origin + actor.camera_error),
		"Online reconciliation must retain the world-space camera correction")
	camera.changes = 0
	for i in range(120):
		actor.render_frame(0, true, true, false)
	assert(camera.changes == 0, "Unchanged correction must not reset and move camera twice")
	actor.camera_error = Vector3(0.2, 0.1, -0.03)
	camera.changes = 0
	actor.render_frame(1.0 / 60.0, true, true, false)
	assert(camera.changes == 1, "Decaying correction must submit one position update")
	assert(camera.global_position.is_equal_approx(eye.global_position + Vector3(0.14, 0.07, -0.021)),
		"Correction decay and rotated-parent world-space offset must remain intact")
	actor.camera_error = Vector3.ZERO
	actor.render_frame(0, true, true, false)
	assert(camera.position == Vector3.ZERO, "Completed reconciliation must reset the offset")
	actor.camera_error = Vector3(0.0001, -0.0001, 0.0001)
	actor.render_frame(0, true, true, false)
	assert(camera.global_position.is_equal_approx(eye.global_position + actor.camera_error),
		"Offsets below the raycast threshold must still be applied")
	assert(camera.position != Vector3.ZERO, "Small correction must not be treated as zero")
	actor.camera_error = Vector3.ZERO
	actor.render_frame(0, true, true, false)
	assert(camera.position == Vector3.ZERO, "Small correction must reset when completed")
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 4, 4)
	collider.shape = box
	wall.add_child(collider)
	root.add_child(wall)
	wall.global_position = eye.global_position + Vector3(0.5, 0, 0)
	await physics_frame
	await physics_frame
	actor.camera_error = Vector3(1, 0, 0)
	camera.changes = 0
	actor.render_frame(0, true, true, false)
	assert(camera.global_position.is_equal_approx(eye.global_position + Vector3(0.33, 0, 0)),
		"Wall correction must retain the 0.12m clearance from the hit surface")
	assert(camera.changes == 1, "Obstructed correction must submit one position update")
	wall.queue_free()
	actor.render_frame(0, false, true, false)
	assert(camera.position == Vector3.ZERO, "Returning to solo must clear an obstructed correction")
	print("CAMERA_CORRECTION_COLLISION_PASS clearance=0.12 position_updates=1 solo_reset=ok")
	print("CAMERA_RENDER_TRANSFORM_PASS solo_ticks=120 online_ticks=120 corrected_ticks=120 stable_notifications=0 decaying_notifications=1 recoil=ok repair=ok reconciliation=ok")
	print("ACTOR_RENDER_TRANSFORM_PASS stable_notifications=0 authority_ticks=120 authority_turn=ok timers=ok small_turn=ok repair=ok interpolation=ok kick=ok")
	actor.queue_free()
	await process_frame
	quit()
