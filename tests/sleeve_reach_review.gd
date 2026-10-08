extends SceneTree
## Measure shoulder drift and elbow extension; this is not a natural-motion test.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	var samples: Array = []
	for weapon in range(3):
		actor.reload_left = 0
		actor.switch_weapon(weapon)
		for tick in range(101):
			var progress := tick / 100.0
			actor.reload_left = actor.RELOAD[weapon] * (1.0 - progress) if tick > 0 and tick < 100 else 0.0
			actor.render_frame(1.0 / 60.0, false, true, false)
			var skeleton: Skeleton3D = actor.first_person.skeleton
			for side in ["L", "R"]:
				var upper := skeleton.find_bone("UpperArm." + side)
				var forearm := skeleton.find_bone("Forearm." + side)
				var hand := skeleton.find_bone("Hand." + side)
				assert(upper >= 0 and forearm >= 0 and hand >= 0)
				var shoulder := skeleton.get_bone_global_pose(upper).origin
				var elbow := skeleton.get_bone_global_pose(forearm).origin
				var wrist := skeleton.get_bone_global_pose(hand).origin
				var upper_length := shoulder.distance_to(elbow)
				var lower_length := elbow.distance_to(wrist)
				assert(upper_length > 0.001 and lower_length > 0.001)
				var angle := rad_to_deg(acos(clampf(
					(shoulder - elbow).normalized().dot((wrist - elbow).normalized()), -1, 1)))
				var camera_shoulder: Vector3 = actor.gun.get_parent().to_local(skeleton.to_global(shoulder))
				samples.append({
					"weapon": weapon, "side": side, "progress": progress,
					"phase": "hold" if tick == 0 or tick == 100 else "reload",
					"shoulder_drift_m": shoulder.distance_to(skeleton.get_bone_global_rest(upper).origin),
					"reach_correction_m": actor.first_person.shoulder_reach_correction.get(side, 0.0),
					"camera_shoulder": [camera_shoulder.x, camera_shoulder.y, camera_shoulder.z],
					"elbow_angle_degrees": angle, "upper_length_m": upper_length,
					"forearm_length_m": lower_length,
					"shoulder": [shoulder.x, shoulder.y, shoulder.z],
					"elbow": [elbow.x, elbow.y, elbow.z],
					"wrist": [wrist.x, wrist.y, wrist.z]
				})
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	var file := FileAccess.open(output.path_join("sleeve-reach.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"diagnostic_only": true,
		"scope": "Direct pose sampling in skeleton space; no continuous motion, ADS, locomotion or visual quality certification.",
		"samples": samples
	}, "\t"))
	file.close()
	print("SLEEVE_REACH_RECORDED samples=%d diagnostic_only=true" % samples.size())
	quit()
