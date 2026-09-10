extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	for other in game.actors.values():
		other.position = Vector3(90, 0.1, 90)
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	actor.yaw = 0
	actor.grounded = true
	actor.lean_input = 1
	for tick in range(20):
		actor.update_lean(1.0 / 60)
	assert(is_equal_approx(actor.lean, 1))
	assert(actor.eye_position().x > 0.35 and actor.body_shape.position.x > 0.15)
	var eye: Vector3 = actor.eye_position()
	actor.render_frame(0, false, true, false)
	assert(actor.camera.global_position.distance_to(eye) < 0.001)
	assert(actor.is_headshot(eye))
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(eye + Vector3(0, 0, 3), eye - Vector3(0, 0, 3), 2)
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty() and hit.collider == actor, "Exposed leaning head is physically hittable")
	game.hit_history.clear()
	game.hit_history.record(10, game.actors)
	var historical: Dictionary = game.hit_history.trace(10, eye + Vector3(0, 0, 3), Vector3.FORWARD, 6, -1, game.actors)
	assert(historical.get("collider") == actor and historical.headshot, "Rewind uses tilted capsule and head coordinates")
	actor.lean_input = 0
	actor.update_lean(1)
	assert(actor.lean == 0)
	var wall = game.world.block(Vector3(0.6, 1.2, 20), Vector3(0.1, 2.4, 4), "465a61")
	await physics_frame
	actor.lean_input = 1
	for tick in range(20):
		actor.update_lean(1.0 / 60)
	assert(actor.lean < 0.8 and actor.eye_position().x < 0.3, "Thin side wall limits lean")
	actor.sprint = true
	actor.update_lean(1)
	assert(actor.lean == 0, "Sprint returns to neutral")
	actor.sprint = false
	actor.grounded = false
	actor.update_lean(1)
	assert(actor.lean == 0, "No airborne lean")
	actor.grounded = true
	wall.queue_free()
	await physics_frame
	actor.crouch = true
	actor.update_stance()
	actor.lean_input = -1
	actor.update_lean(1)
	assert(actor.lean == -1 and actor.eye_position().x < -0.17 and actor.eye_position().y < 1.1)
	var packed: Dictionary = actor.pack()
	var remote = game.actors[-2]
	remote.unpack(packed, false)
	assert(remote.lean == -1 and remote.body_shape.rotation.z > 0)
	var cmd: Dictionary = game.local_command(actor)
	cmd.lean = NAN
	assert(not game.valid_command(cmd))
	cmd.lean = 2
	assert(not game.valid_command(cmd))
	cmd.lean = -1
	assert(game.valid_command(cmd))
	game.ui.set_map(true)
	Input.action_press("lean_right")
	assert(game.local_command(actor).lean == 0, "Map suppresses lean input")
	Input.action_release("lean_right")
	if "--capture-lean" in OS.get_cmdline_user_args():
		game.ui.set_map(false)
		actor.crouch = false
		actor.set_stance(false)
		actor.body_mesh.visible = true
		actor.render_frame(0, false, false, false)
		remote.position = Vector3(2, 0.02, 20)
		remote.lean = 1
		remote.set_stance(false)
		remote.render_frame(0, false, false, false)
		var view := Camera3D.new()
		game.add_child(view)
		view.position = Vector3(1, 2.1, 24)
		view.look_at(Vector3(1, 1, 20))
		view.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/leaning.png")
	print("LEAN_RULES_PASS eye_collision=ok headshot=ok rewind=ok wall=ok sprint_air=ok crouch=ok snapshot=ok input_validation=ok menu=ok")
	game.queue_free()
	await process_frame
	quit()
