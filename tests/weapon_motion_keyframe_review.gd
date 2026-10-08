extends "weapon_motion_review_capture.gd"

# Sparse real-game contact samples; explicitly NOT the 10 Hz motion acceptance.
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WEAPON_KEYFRAME_REVIEW_REQUIRES_RENDERING: run with a graphical display; headless cannot provide screenshot evidence.")
		quit(1)
		return
	RenderingServer.render_loop_enabled = false
	output = OS.get_environment("CAPTURE_ARTIFACT_DIR")
	capture_started = Time.get_ticks_msec()
	compact = true
	root.content_scale_size = Vector2i(640, 400)
	root.size = Vector2i(640, 400)
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	diagnostic_lighting(game.world)
	RenderingServer.render_loop_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	actor = game.actors[game.local_id]
	world_visible = true
	cull_distant_details(game.world)
	for other in game.actors.values():
		if other != actor:
			other.hide()
	actor.aiming = false
	actor.reload_left = 0
	for weapon in [0, 1, 2]:
		actor.switch_weapon(weapon)
		await advance(60, false)
		await reload_clip("first-weapon-%d" % weapon, false)
	actor.position = Vector3(0, 0.3, 68)
	actor.velocity = Vector3.ZERO
	actor.local_view = false
	actor.body_mesh.visible = true
	game.ui.hide()
	review_camera = Camera3D.new()
	game.add_child(review_camera)
	review_camera.fov = 42
	review_camera.make_current()
	for crouch in [false, true]:
		actor.crouch = crouch
		actor.set_stance(crouch)
		for weapon in [0, 1, 2]:
			actor.switch_weapon(weapon)
			await advance(60, true)
			review_camera.position = actor.position + Vector3(2.8, 1.5, -3)
			review_camera.look_at(actor.position + Vector3(0, 0.95, 0), Vector3.UP)
			await reload_clip("third-%s-weapon-%d" % ["crouch" if crouch else "stand", weapon], true)
	var file := FileAccess.open(output.path_join("keyframe-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"complete": true, "samples": records, "world_visible": true,
		"renderer": RenderingServer.get_current_rendering_method(),
		"shadows_disabled": true, "viewport": [root.size.x, root.size.y],
		"culled_detail_meshes": culled_details, "culled_detail_instances": culled_instances,
		"scope": "Nine reloads, five sparse keyframes each. Contact diagnosis only; no continuous motion, intermediate contact, locomotion, networking or production lighting acceptance.",
		"simulation_step": 1.0 / 60.0
	}, "\t"))
	file.close()
	print("WEAPON_KEYFRAME_REVIEW_PASS")
	quit()

func reload_clip(label: String, third: bool) -> void:
	var before: int = actor.ammo
	game.shoot(actor)
	assert(actor.ammo == before - 1)
	await advance(24, third)
	actor.reload_weapon()
	assert(actor.reload_left > 0)
	clip_frame = 0
	var duration := ceili(actor.RELOAD[actor.weapon] * 60)
	for target in [0, roundi(duration * 0.25), roundi(duration * 0.5), roundi(duration * 0.75), duration + 12]:
		await advance(target - clip_frame, third)
		clip_frame = target
		if not third:
			game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		await capture("%s-frame-%03d" % [label, clip_frame])
	assert(actor.reload_left <= 0 and actor.ammo == actor.CAPACITY[actor.weapon])
