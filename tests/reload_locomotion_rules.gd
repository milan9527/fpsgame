extends SceneTree

# Continuous animation evaluation with prescribed velocity, not an input,
# floor-contact, network, or visual-naturalness test.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var moving = load("res://scripts/actor.gd").new()
	var still = load("res://scripts/actor.gd").new()
	root.add_child(moving)
	root.add_child(still)
	await process_frame
	var samples: Array = []
	var passed := true
	for weapon in range(3):
		for gait in ["walk", "run", "crouch"]:
			for actor in [moving, still]:
				actor.weapon = weapon
				actor.crouch = gait == "crouch"
				actor.update_stance()
				actor.grounded = true
				actor.character_animation.player.stop()
				actor.character_animation.active_clip = ""
				actor.update_weapon_visuals(true)
			moving.velocity = Vector3(0, 0, 2.8 if gait == "crouch" else (8.0 if gait == "run" else 4.5))
			var sk: Skeleton3D = moving.character_animation.skeleton
			var reference: Skeleton3D = still.character_animation.skeleton
			var foot := sk.find_bone("Foot.L")
			var hip := sk.find_bone("Hips")
			var first_foot := Vector3.ZERO
			var excursion := 0.0
			var upper_error := 0.0
			for frame in range(120):
				for actor in [moving, still]:
					actor.reload_left = actor.RELOAD[weapon] * (1.0 - float(frame) / 140.0)
					actor.character_animation.update(actor, 1.0 / 60.0)
					actor.character_animation.skeleton.force_update_all_bone_transforms()
					actor.update_weapon_attachment()
				var relative_foot := sk.get_bone_global_pose(foot).origin - sk.get_bone_global_pose(hip).origin
				if frame == 15:
					first_foot = relative_foot
				elif frame > 15:
					excursion = maxf(excursion, relative_foot.distance_to(first_foot))
				for name in ["Spine", "UpperArm.L", "Forearm.L", "Hand.L", "Hand.R", "Weapon"]:
					var bone := sk.find_bone(name)
					upper_error = maxf(upper_error, sk.get_bone_global_pose(bone).origin.distance_to(reference.get_bone_global_pose(bone).origin))
			var case_pass := excursion > 0.08 and upper_error < 0.0001
			passed = passed and case_pass
			samples.append({"weapon": weapon, "gait": gait, "foot_excursion_m": excursion,
				"upper_body_difference_m": upper_error, "passed": case_pass})
			print("RELOAD_GAIT weapon=", weapon, " gait=", gait, " excursion=", excursion, " upper_error=", upper_error)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("reload-locomotion.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": passed, "samples": samples,
			"scope": "120 continuous animation frames per case; prescribed velocity. No actual traversal, foot planting, rendered motion, input or network verification."}, "\t"))
	print("RELOAD_LOCOMOTION_PASS" if passed else "RELOAD_LOCOMOTION_FAIL")
	moving.free()
	still.free()
	quit(0 if passed else 1)
