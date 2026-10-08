extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await process_frame
	var samples: Array = []
	var passed := true
	for weapon in range(3):
		for gait in ["Walk", "Run", "CrouchWalk"]:
			for duration in [37, 61, 89]:
				actor.weapon = weapon
				actor.crouch = gait == "CrouchWalk"
				actor.update_stance()
				actor.grounded = true
				actor.velocity = Vector3(0, 0, 2.8 if actor.crouched else (8.0 if gait == "Run" else 4.5))
				var controller = actor.character_animation
				controller.player.stop()
				controller.active_clip = ""
				controller.gait_phase = 0.0
				controller.reload_gait_weight = 0.0
				for frame in range(duration):
					actor.reload_left = actor.RELOAD[weapon] * (1.0 - float(frame) / duration)
					controller.update(actor, 1.0 / 60.0)
				var phase: float = controller.gait_phase
				var anim: Animation = controller.player.get_animation(controller.clips[gait])
				actor.reload_left = 0.0
				var phase_error := 0.0
				var leg_error := 0.0
				for frame in range(10):
					controller.update(actor, 1.0 / 60.0)
					phase = fposmod(phase + 1.0 / 60.0 / anim.length, 1.0)
					var difference: float = absf(controller.gait_phase - phase)
					phase_error = maxf(phase_error, minf(difference, 1.0 - difference))
					for track in anim.get_track_count():
						var path := anim.track_get_path(track)
						var bone_name := String(path.get_subname(0)) if path.get_subname_count() else ""
						if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D or not (bone_name.begins_with("Thigh.") or bone_name.begins_with("Shin.") or bone_name.begins_with("Foot.")):
							continue
						var bone: int = controller.skeleton.find_bone(bone_name)
						var actual: Quaternion = controller.skeleton.get_bone_pose_rotation(bone)
						leg_error = maxf(leg_error, actual.angle_to(anim.rotation_track_interpolate(track, phase * anim.length)))
				var ok := phase_error < 0.001 and leg_error < 0.01
				passed = passed and ok
				samples.append({"weapon": weapon, "gait": gait, "reload_frames": duration,
					"phase_error": phase_error, "leg_rotation_error_radians": leg_error, "passed": ok})
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("reload-exit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "samples": samples,
		"scope": "27 prescribed-velocity reload exits, ten consecutive evaluated frames each. Does not verify physical foot planting or natural rendered movement."}, "\t"))
	print("RELOAD_EXIT_PASS" if passed else "RELOAD_EXIT_FAIL")
	actor.free()
	quit(0 if passed else 1)
