extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[1]
	var target = game.actors[-1]
	for other in game.actors.values():
		other.position = Vector3(1000, 80, other.actor_id * 5)
	actor.position = Vector3(0, 80, 0)
	actor.yaw = 0.4
	actor.pitch = 0.15
	actor.recoil = 0.03
	var samples := 0
	for weapon in range(3):
		actor.switch_weapon(weapon)
		for lean in [-1.0, 0.0, 1.0]:
			actor.lean = lean
			actor.first_person.aim_blend = 0.0
			for frame in range(12):
				actor.weapon_kick = 1.0 if frame >= 9 else 0.0
				actor.render_frame(1.0 / 60, false, true, true)
				var camera_ray: Vector3 = -actor.camera.global_basis.z.normalized()
				var ballistic_ray: Vector3 = Basis(Vector3.UP, actor.yaw) * Basis(Vector3.RIGHT, clampf(actor.pitch + actor.recoil, -1.5, 1.5)) * Vector3.FORWARD
				if not check(camera_ray.distance_to(ballistic_ray) < 0.0001, "Camera and ballistic directions disagree"): return
				if not check(actor.camera.global_position.distance_to(actor.eye_position()) < 0.001, "Camera and firing origins disagree"): return
				if not check(not actor.first_person.sight_dot.visible, "Animated gun red dot misrepresents the ballistic center"): return
				target.position = actor.eye_position() + camera_ray * 40 - Vector3.UP * 0.9
				await physics_frame
				await physics_frame
				var hit: Dictionary = game.trace_shot(actor, actor.eye_position(), ballistic_ray, 0)
				if hit.is_empty() or hit.collider != target:
					print("MISS weapon=", weapon, " frame=", frame, " target=", target.position, " eye=", actor.eye_position(), " hit=", hit)
				if not check(not hit.is_empty() and hit.collider == target, "Camera-center target was missed by authoritative trace"): return
				samples += 1
	game.ui.sight_aiming = true
	game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
	if DisplayServer.get_name() != "headless" and OS.has_environment("CAPTURE_ARTIFACT_DIR"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_ARTIFACT_DIR").path_join("aim-alignment.png"))
	print("AIM_ALIGNMENT_PASS samples=%d weapons=3 transitions=ok recoil=ok lean=ok raycast=ok" % samples)
	game.queue_free()
	await process_frame
	quit()
