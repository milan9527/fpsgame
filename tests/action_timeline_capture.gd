extends SceneTree

# Advance simulation and animation at 60 Hz. Render selected samples only:
# this is action inspection evidence, never a rendering performance benchmark.
var game
var actor
var output: String
var samples := []
var tick := 0
var third_person := false
var review_camera: Camera3D
var shot_events := []
var last_shot_tick := -1000
var recovery_checks := []

func save_checkpoint() -> void:
	# Keep rendered-image metadata even if a long software-rendering run stops.
	# This file never asserts that the entire timeline passed.
	var path := output.path_join("action-timeline.partial.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"simulation_step": 1.0 / 60.0,
		"rendered_images": true, "complete": false, "passed": false,
		"shot_events": shot_events, "samples": samples,
		"recovery_checks": recovery_checks,
		"note": "Incremental rendered samples only; full validation requires action-timeline.json."}, "\t"))
	file.close()
	assert(DirAccess.rename_absolute(path + ".tmp", path) == OK)

func transform_record(value: Transform3D) -> Dictionary:
	return {"origin": [value.origin.x, value.origin.y, value.origin.z],
		"basis": [[value.basis.x.x, value.basis.x.y, value.basis.x.z],
			[value.basis.y.x, value.basis.y.y, value.basis.y.z],
			[value.basis.z.x, value.basis.z.y, value.basis.z.z]]}

func shoot_recorded(label: String) -> void:
	var before: int = actor.ammo
	game.shoot(actor)
	if actor.ammo == before - 1:
		last_shot_tick = tick
		shot_events.append({"tick": tick, "action": label, "weapon": actor.weapon,
			"ammo_before": before, "ammo_after": actor.ammo})

func should_capture(label: String, frame: int, frames: int) -> bool:
	if label.begins_with("settle-recovery-"):
		return false
	# One predicate: no outer modulo filter can discard +3/+6 samples.
	if label.begins_with("sustained-fire-") and OS.get_environment("REVIEW_KEYFRAMES") == "1":
		# Record every shot in JSON; render only the first burst and its end.
		return (frame < 6 and tick - last_shot_tick in [1, 3, 6]) or frame == frames - 1
	if label.begins_with("fire-") or label.begins_with("sustained-fire-") or label.begins_with("recovery-"):
		return tick - last_shot_tick in [1, 3, 6, 24] or frame == frames - 1
	if OS.get_environment("REVIEW_KEYFRAMES") != "1":
		return frame % 12 == 0 or frame == frames - 1
	if label == "settle":
		return false
	if label.begins_with("reload-") or label.begins_with("third-"):
		# Preserve the animation simulation; render its start, middle and end.
		# Reload additionally needs the magazine transfer quarters.
		if "reload" in label:
			return frame in [0, frames / 4, frames / 2, frames * 3 / 4, frames - 1]
		return frame in [0, frames / 2, frames - 1]
	if label.begins_with("switch-") or label.begins_with("ads-"):
		return frame in [0, 12, 24] or frame == frames - 1
	return frame == frames - 1

func _initialize() -> void:
	call_deferred("run")

func advance(label: String, frames: int) -> void:
	print("ACTION_BEGIN label=", label, " tick=", tick, " wall_ms=", Time.get_ticks_msec())
	for frame in range(frames):
		# Stationary actions still advance every animation/simulation step, but
		# need a physics boundary only at captured samples. Moving actors use
		# every boundary so move_and_slide observes each collision update.
		if actor.move_input != Vector2.ZERO or frame % 12 == 0:
			await physics_frame
		if label.begins_with("sustained-fire-"):
			# Match single-shot ordering: accepted shot, then one simulated tick.
			shoot_recorded(label)
		actor.simulate(1.0 / 60.0)
		if label == "third-crouch-walk":
			assert(actor.crouched)
		actor.render_frame(1.0 / 60.0, false, not third_person, actor.aiming)
		tick += 1
		if third_person:
			review_camera.position = actor.position + Vector3(2.8, 1.5, -3.0)
			review_camera.look_at(actor.position + Vector3(0, 0.95, 0), Vector3.UP)
		if not should_capture(label, frame, frames):
			continue
		# Match game.gd's visual ADS threshold, including the transition.
		game.ui.sight_aiming = not third_person and actor.first_person.aim_blend > 0.5
		game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
		assert(game.ui.sight_aiming == (not third_person and actor.first_person.aim_blend > 0.5))
		# Flush deferred Node3D transforms before explicitly rendering a sample.
		# Otherwise a newly shown replacement magazine can render at its rest pose.
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var filename := "%04d-%s.png" % [tick, label]
		assert(root.get_texture().get_image().save_png(output.path_join(filename)) == OK)
		var camera := root.get_camera_3d()
		var visibility_checks := 0
		var forearm_lengths := {}
		var wrist_world := {}
		for side in ["L", "R"]:
			var rig: Skeleton3D = actor.first_person.skeleton
			var elbow := rig.find_bone("Forearm." + side)
			var wrist := rig.find_bone("Hand." + side)
			var rest_length := rig.get_bone_global_rest(elbow).origin.distance_to(rig.get_bone_global_rest(wrist).origin)
			var pose_length := rig.get_bone_global_pose(elbow).origin.distance_to(rig.get_bone_global_pose(wrist).origin)
			forearm_lengths[side] = {"rest_m": rest_length, "pose_m": pose_length}
			wrist_world[side] = transform_record(rig.global_transform * rig.get_bone_global_pose(wrist))
			assert(abs(pose_length - rest_length) < 0.003, "Forearm stretched during " + label)
		if third_person:
			# A successful timeline cannot accept frames hidden behind a wall.
			# Check head, torso and both legs from the actual capture camera.
			for offset in [Vector3(0, 1.0 if actor.crouched else 1.65, 0),
					Vector3(0, 0.7 if actor.crouched else 1.0, 0),
					Vector3(-0.16, 0.25, 0), Vector3(0.16, 0.25, 0)]:
				var query := PhysicsRayQueryParameters3D.create(
					camera.global_position, actor.global_position + offset, 1, [actor.get_rid()])
				var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
				if not hit.is_empty():
					push_error("Third-person sample occluded: %s %s" % [label, hit])
					quit(1)
					return
				visibility_checks += 1
		samples.append({"tick": tick, "simulation_seconds": tick / 60.0,
			"last_shot_tick": last_shot_tick, "ticks_since_shot": tick - last_shot_tick,
			"camera_world": transform_record(camera.global_transform),
			"weapon_world": transform_record(actor.first_person.weapon_model.global_transform),
			"wrist_world": wrist_world,
			"action": label, "weapon": actor.weapon, "ammo": actor.ammo,
			"aiming": actor.aiming, "fire_left": actor.fire_left,
			"aim_blend": actor.first_person.aim_blend, "sight_aiming": game.ui.sight_aiming,
			"weapon_kick": actor.weapon_kick,
			"reload_left": actor.reload_left, "recoil": actor.recoil,
			"first_person_clip": actor.first_person.active_clip,
			"forearm_lengths": forearm_lengths,
			"magazine_position": str(actor.first_person.magazine.position),
			"animation": actor.character_animation.active_clip,
			"grounded": actor.grounded,
			"left_hand": str(actor.character_animation.skeleton.get_bone_global_pose(actor.character_animation.skeleton.find_bone("Hand.L")).origin),
			"crouched": actor.crouched, "sprint": actor.sprint,
			"position": str(actor.position), "velocity": str(actor.velocity),
			"camera_position": str(camera.global_position),
			"camera_rotation": str(camera.global_rotation),
			"action_frame": frame, "action_frames": frames,
			"unobstructed_body_rays": visibility_checks, "image": filename})
		save_checkpoint()
		print("ACTION_SAMPLE image=", filename, " wall_ms=", Time.get_ticks_msec())
	print("ACTION_END label=", label, " tick=", tick, " wall_ms=", Time.get_ticks_msec())

func run() -> void:
	RenderingServer.render_loop_enabled = false
	print("ACTION_INIT begin wall_ms=", Time.get_ticks_msec())
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	print("ACTION_INIT game_ready wall_ms=", Time.get_ticks_msec())
	game.start_solo()
	print("ACTION_INIT world_ready wall_ms=", Time.get_ticks_msec())
	game.set_physics_process(false)
	game.set_process(false)
	actor = game.actors[game.local_id]
	output = OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	save_checkpoint()
	actor.position = Vector3(17, 0.3, 50)
	actor.velocity = Vector3.ZERO
	actor.yaw = 0.0
	actor.pitch = 0.1
	await advance("settle", 30)
	var weapons := [] if OS.get_environment("REVIEW_THIRD_ONLY") == "1" else [0, 1, 2]
	var requested_weapon := OS.get_environment("REVIEW_WEAPON")
	if not requested_weapon.is_empty():
		assert(OS.get_environment("REVIEW_THIRD_ONLY") != "1")
		assert(requested_weapon in ["0", "1", "2"])
		weapons = [int(requested_weapon)]
	for weapon in weapons:
		if weapon != actor.weapon:
			actor.switch_weapon(weapon)
			await advance("switch-%d" % weapon, 36)
		assert(actor.weapon == weapon)
		actor.aiming = false
		await advance("hip-%d" % weapon, 24)
		actor.aiming = true
		await advance("ads-%d" % weapon, 36)
		var neutral_camera: Transform3D = actor.camera.transform
		var neutral_gun: Transform3D = actor.gun.transform
		var old_ammo: int = actor.ammo
		shoot_recorded("fire-%d" % weapon)
		assert(actor.ammo == old_ammo - 1)
		await advance("fire-%d" % weapon, 24)
		old_ammo = actor.ammo
		await advance("sustained-fire-%d" % weapon, 168)
		assert(actor.ammo <= old_ammo - 2, "Repeated shooting did not consume two rounds")
		await advance("recovery-%d" % weapon, 48)
		var recovery_ticks := 48
		while (actor.recoil > 0.00001 or actor.weapon_kick > 0.00001) and recovery_ticks < 240:
			await advance("settle-recovery-%d" % weapon, 1)
			recovery_ticks += 1
		await advance("recovery-neutral-%d" % weapon, 1)
		var camera_error: float = actor.camera.transform.basis.get_rotation_quaternion().angle_to(neutral_camera.basis.get_rotation_quaternion())
		var gun_position_error: float = actor.gun.position.distance_to(neutral_gun.origin)
		var gun_angle_error: float = actor.gun.transform.basis.get_rotation_quaternion().angle_to(neutral_gun.basis.get_rotation_quaternion())
		assert(actor.recoil <= 0.00001 and actor.weapon_kick <= 0.00001, "Recovery timed out")
		assert(camera_error < 0.0001 and gun_position_error < 0.0001 and gun_angle_error < 0.0001, "Camera or gun did not return to ADS baseline")
		recovery_checks.append({"weapon": weapon, "ticks": recovery_ticks + 1,
			"recoil": actor.recoil, "weapon_kick": actor.weapon_kick,
			"camera_angle_error_rad": camera_error, "gun_position_error_m": gun_position_error,
			"gun_angle_error_rad": gun_angle_error})
		actor.aiming = false
		actor.reload_weapon()
		assert(actor.reload_left > 0)
		await advance("reload-%d" % weapon, int(ceil(actor.RELOAD[weapon] * 60)) + 12)
		assert(actor.reload_left <= 0 and actor.ammo == actor.CAPACITY[weapon])
	if requested_weapon.is_empty():
		third_person = true
		# Use the central road, clear of depot perimeter walls for the whole route.
		actor.position = Vector3(0, 0.3, 68)
		actor.velocity = Vector3.ZERO
		actor.local_view = false
		actor.body_mesh.visible = true
		game.ui.hide()
		review_camera = Camera3D.new()
		game.add_child(review_camera)
		review_camera.fov = 42
		review_camera.make_current()
		actor.move_input = Vector2(0, -1)
		await advance("third-walk", 48)
		actor.sprint = true
		await advance("third-run", 48)
		actor.sprint = false
		actor.crouch = true
		actor.set_stance(true)
		actor.move_input = Vector2.ZERO
		await advance("third-crouch-down", 24)
		actor.move_input = Vector2(0, -1)
		await advance("third-crouch-walk", 48)
		actor.move_input = Vector2.ZERO
		game.shoot(actor)
		await advance("third-crouch-fire", 24)
		actor.reload_weapon()
		assert(actor.reload_left > 0)
		await advance("third-crouch-reload", 192)
		assert(actor.reload_left <= 0)
		actor.crouch = false
		actor.set_stance(false)
		await advance("third-stand-up", 24)
		game.shoot(actor)
		await advance("third-fire", 24)
		actor.reload_weapon()
		assert(actor.reload_left > 0)
		await advance("third-reload", 192)
		assert(actor.reload_left <= 0)
	var file := FileAccess.open(output.path_join("action-timeline.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"simulation_step": 1.0 / 60.0,
		"capture_policy": "shots +1/+3/+6/+24 ticks; REVIEW_KEYFRAMES reduces locomotion to start/middle/end and reload to quarters",
		"shot_tick_convention": "shot accepted at tick boundary before next simulation step",
		"shot_events": shot_events, "samples": samples,
		"recovery_checks": recovery_checks,
		"note": "Solo actor simulation and animation advance; other actors frozen. Sampled rendering, not FPS proof.",
		"scope": {"weapons": weapons, "third_person": third_person},
		"complete": true, "passed": true}, "\t"))
	file.close()
	print("ACTION_TIMELINE_PASS samples=%d ticks=%d" % [samples.size(), tick])
	quit()
