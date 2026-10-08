extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var actor = load("res://scripts/actor.gd").new()
	actor.mobile_animation = "--mobile-character" in OS.get_cmdline_user_args()
	scene.add_child(actor)
	actor.set_local()
	await process_frame
	var samples := 0
	for weapon in range(3):
		actor.reload_left = 0
		actor.switch_weapon(weapon)
		var fp = actor.first_person
		for tick in range(1, 100):
			var progress := tick / 100.0
			actor.reload_left = actor.RELOAD[weapon] * (1.0 - progress)
			# Duration arithmetic may round a nominal boundary below 0.6.
			var rendered_progress := clampf(1 - actor.reload_left / actor.RELOAD[weapon], 0, 1)
			actor.render_frame(1.0 / 60.0, false, true, false)
			for side in ["L", "R"]:
				var shoulder: int = fp.skeleton.find_bone("UpperArm." + side)
				assert(shoulder >= 0, "Sleeve needs an independent upper arm")
				var elbow: int = fp.skeleton.find_bone("Forearm." + side)
				var wrist: int = fp.skeleton.find_bone("Hand." + side)
				var upper_rest: float = fp.skeleton.get_bone_global_rest(shoulder).origin.distance_to(
					fp.skeleton.get_bone_global_rest(elbow).origin)
				var upper_pose: float = fp.skeleton.get_bone_global_pose(shoulder).origin.distance_to(
					fp.skeleton.get_bone_global_pose(elbow).origin)
				assert(absf(upper_pose - upper_rest) < 0.003, "Reload must preserve upper arm length")
				var rest_length: float = fp.skeleton.get_bone_global_rest(elbow).origin.distance_to(
					fp.skeleton.get_bone_global_rest(wrist).origin)
				var pose_length: float = fp.skeleton.get_bone_global_pose(elbow).origin.distance_to(
					fp.skeleton.get_bone_global_pose(wrist).origin)
				assert(absf(pose_length - rest_length) < 0.003,
					"Reload must preserve forearm length throughout reach, insertion and return")
			if tick >= 20 and tick <= 86:
				assert(fp.reload_contact_error < 0.001, "Palm must follow magazine throughout extraction/insertion")
				var hand_index: int = fp.skeleton.find_bone("Hand.L")
				var hand_rest: Transform3D = fp.skeleton.get_bone_global_rest(hand_index)
				var palm_local: Vector3 = hand_rest.basis.inverse() * Vector3(0, 0, -0.023)
				var actual_palm: Vector3 = fp.skeleton.to_global(
					fp.skeleton.get_bone_global_pose(hand_index) * palm_local)
				var magazine_bounds: AABB = fp.held_magazine.get_aabb()
				var contact := magazine_bounds.get_center()
				contact.x = magazine_bounds.position.x - 0.018
				assert(actual_palm.distance_to(fp.held_magazine.to_global(contact)) < 0.001,
					"Applied skeleton pose must follow the rendered magazine")
				samples += 1
			if tick <= 20 or tick >= 86:
				assert(fp.magazine.position.distance_to(fp.magazine_rest) < 0.001, "Magazine stays seated during reach/release")
			if rendered_progress >= 0.6 and rendered_progress < 0.86:
				assert(fp.held_magazine != fp.magazine and fp.replacement_magazine.visible and not fp.magazine.visible,
					"Insertion uses a distinct replacement; empty well has no seated duplicate")
			else:
				assert(fp.magazine.visible and not fp.replacement_magazine.visible)
		actor.reload_left = 0
		for frame in range(12):
			actor.render_frame(1.0 / 60.0, false, true, true)
		assert(fp.magazine.position.distance_to(fp.magazine_rest) < 0.0001)
		assert(not fp.replacement_magazine.visible)
		var hand: int = fp.skeleton.find_bone("Hand.L")
		assert(fp.skeleton.get_bone_global_pose(hand).origin.distance_to(
			fp.skeleton.get_bone_global_pose_no_override(hand).origin) < 0.0001, "Hold clears reload override")
		# Interrupt while either magazine is in the hand. No detached magazine
		# may remain visible after returning to aim.
		for progress in [0.35, 0.6]:
			actor.reload_left = actor.RELOAD[weapon] * (1.0 - progress)
			actor.render_frame(1.0 / 60.0, false, true, false)
			actor.reload_left = 0
			actor.render_frame(1.0 / 60.0, false, true, true)
			assert(fp.magazine.visible and not fp.replacement_magazine.visible)
			assert(fp.held_magazine == fp.magazine)
			assert(fp.magazine.position.distance_to(fp.magazine_rest) < 0.0001)
	print("RELOAD_CONTACT_RULES_PASS weapons=3 contact_samples=%d forearm_length_samples=594 seated_reach_release=ok hold_reset=ok interrupted_phases=6" % samples)
	quit()
