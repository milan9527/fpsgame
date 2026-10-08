extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	root.add_child(actor)
	await process_frame
	actor.grounded = true
	var samples: Array = []
	for weapon in range(3):
		actor.weapon = weapon
		actor.reload_left = 0
		actor.update_weapon_visuals(true)
		assert(actor.third_person_magazine != null, "Every weapon needs its imported magazine")
		for crouch in [false, true]:
			actor.crouch = crouch
			actor.update_stance()
			actor.character_animation.player.stop()
			actor.character_animation.active_clip = ""
			var hand_positions: Array[Vector3] = []
			var magazine_positions: Array[Vector3] = []
			for progress in [0.18, 0.40, 0.55, 0.73]:
				actor.reload_left = actor.RELOAD[weapon] * (1.0 - progress)
				var animation = actor.character_animation
				animation.update(actor, 0.0)
				var clip = animation.player.get_animation(animation.clips[animation.active_clip])
				# Sample authored poses directly, without a previous stance's blend.
				animation.player.play(animation.clips[animation.active_clip], 0.0)
				animation.player.seek(clip.length * progress, true)
				animation.skeleton.force_update_all_bone_transforms()
				actor.update_weapon_attachment()
				var hand: Vector3 = animation.skeleton.global_transform * animation.skeleton.get_bone_global_pose(animation.skeleton.find_bone("Hand.L")).origin
				var magazine: Vector3 = actor.third_person_magazine.global_position
				# The chest now follows the reach. Compare manipulation in the
				# moving weapon frame so body motion cannot mask grip slippage.
				hand_positions.append(actor.third_person_gun.to_local(hand))
				magazine_positions.append(actor.third_person_gun.to_local(magazine))
				samples.append({"weapon": weapon, "crouch": crouch, "progress": progress,
					"hand": [hand.x, hand.y, hand.z], "magazine": [magazine.x, magazine.y, magazine.z]})
			var hand_travel := hand_positions[1] - hand_positions[0]
			var magazine_travel := magazine_positions[1] - magazine_positions[0]
			print("RELOAD_TRAVEL weapon=", weapon, " crouch=", crouch, " hand=", hand_travel, " magazine=", magazine_travel)
			assert(magazine_travel.length() > 0.35, "Magazine must leave the socket")
			assert(hand_travel.distance_to(magazine_travel) < 0.035, "Magazine follows the authored wrist to the belt")
			assert(magazine_positions[3].distance_to(magazine_positions[0]) < 0.025, "Magazine returns to socket")
			actor.reload_left = 0
			actor.update_weapon_attachment()
			assert(actor.third_person_magazine.transform.is_equal_approx(actor.third_person_magazine_rest), "Interrupted reload restores the magazine")
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("third-person-reload.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": true, "samples": samples}, "\t"))
	print("THIRD_PERSON_RELOAD_PASS weapons=3 stances=2")
	root.remove_child(actor)
	actor.free()
	quit()
