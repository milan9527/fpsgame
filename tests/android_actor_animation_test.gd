extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var view := Camera3D.new()
	scene.add_child(view)
	view.make_current()
	var actor = load("res://scripts/actor.gd").new()
	scene.add_child(actor)
	actor.mobile_animation = true
	actor.position = Vector3(100, 0, 100)
	actor.grounded = true
	actor.velocity = Vector3.ZERO
	assert(actor.character_animation.available)
	actor.update_visual_animation(0.01, false)
	assert(actor.character_animation.active_clip == "Idle")
	actor.update_visual_animation(0.01, false)
	assert(is_equal_approx(actor.animation_cadence.elapsed, 0.01))
	# Remote movement still interpolates on a frame where the pose is skipped.
	var before: Vector3 = actor.position
	actor.target_position = before + Vector3(10, 0, 0)
	actor.render_frame(0.01, true, false, false)
	assert(actor.position.is_equal_approx(before + Vector3(2, 0, 0)))
	assert(is_equal_approx(actor.animation_cadence.elapsed, 0.02))
	actor.set_stance(true)
	actor.update_visual_animation(0.001, false)
	assert(actor.character_animation.active_clip == "CrouchIdle")
	assert(actor.animation_cadence.elapsed == 0)
	actor.reload_left = 1.5
	actor.update_visual_animation(0.001, false)
	assert(actor.character_animation.active_clip == "CrouchReload")
	actor.alive = false
	actor.update_visual_animation(0.001, false)
	assert(actor.character_animation.active_clip == "Death")
	actor.update_visual_animation(0.01, true)
	assert(actor.animation_cadence.elapsed == 0)
	# Near actors remain full-rate on both sides of the camera; far local-view
	# actors must also bypass cadence even when the caller's local flag is false.
	for point in [Vector3(0, 0, -10), Vector3(0, 0, 10)]:
		actor.position = point
		actor.update_visual_animation(0.001, false)
		assert(actor.animation_cadence.elapsed == 0)
	actor.position = Vector3(100, 0, 100)
	actor.local_view = true
	actor.update_visual_animation(0.001, false)
	assert(actor.animation_cadence.elapsed == 0)
	actor.local_view = false
	actor.update_visual_animation(0.001, false)
	assert(is_equal_approx(actor.animation_cadence.elapsed, 0.001))
	print("PASS Android actor: sampled pose, continuous network movement, immediate stance/reload/death")
	scene.queue_free()
	await process_frame
	quit()
