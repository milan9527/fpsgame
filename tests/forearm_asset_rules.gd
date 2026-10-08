extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var mobile := "--mobile-character" in OS.get_cmdline_user_args()
	var asset := "res://assets/first_person_mobile.glb" if mobile else "res://assets/first_person.glb"
	var model = load(asset).instantiate()
	root.add_child(model)
	var rig: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var reference: Node3D
	var reference_rig: Skeleton3D
	var reference_player: AnimationPlayer
	if mobile:
		reference = load("res://assets/first_person.glb").instantiate()
		root.add_child(reference)
		reference_rig = reference.find_children("*", "Skeleton3D", true, false)[0]
		reference_player = reference.find_children("*", "AnimationPlayer", true, false)[0]
		assert(rig.get_bone_count() == reference_rig.get_bone_count())
		for bone in range(rig.get_bone_count()):
			assert(rig.get_bone_name(bone) == reference_rig.get_bone_name(bone))
			assert(rig.get_bone_parent(bone) == reference_rig.get_bone_parent(bone))
			assert(rig.get_bone_rest(bone).is_equal_approx(reference_rig.get_bone_rest(bone)), "Mobile bone rest changed")
		assert(player.get_animation_list() == reference_player.get_animation_list())
	var lengths := {}
	for side in ["L", "R"]:
		var elbow := rig.find_bone("Forearm." + side)
		var wrist := rig.find_bone("Hand." + side)
		lengths[side] = rig.get_bone_global_rest(elbow).origin.distance_to(rig.get_bone_global_rest(wrist).origin)
		# tools/build_viewmodel.py authors a 0.26 m forearm.
		assert(absf(lengths[side] - 0.26) < 0.003, "Forearm must retain authored length")
	assert(lengths.L / lengths.R > 0.95 and lengths.L / lengths.R < 1.05)
	var samples := 0
	var max_error := 0.0
	for clip in player.get_animation_list():
		if clip == "RESET":
			continue
		player.play(clip)
		var animation := player.get_animation(clip)
		if mobile:
			assert(is_equal_approx(animation.length, reference_player.get_animation(clip).length))
			reference_player.play(clip)
		for frame in range(int(ceil(animation.length * 60)) + 1):
			player.seek(minf(frame / 60.0, animation.length), true)
			rig.force_update_all_bone_transforms()
			if mobile:
				reference_player.seek(minf(frame / 60.0, animation.length), true)
				reference_rig.force_update_all_bone_transforms()
				for bone in range(rig.get_bone_count()):
					assert(rig.get_bone_global_pose(bone).is_equal_approx(reference_rig.get_bone_global_pose(bone)), "Mobile animation changed: " + clip)
			for side in ["L", "R"]:
				var elbow := rig.find_bone("Forearm." + side)
				var wrist := rig.find_bone("Hand." + side)
				var length := rig.get_bone_global_pose(elbow).origin.distance_to(rig.get_bone_global_pose(wrist).origin)
				max_error = maxf(max_error, absf(length - lengths[side]))
				assert(absf(length - lengths[side]) < 0.003, "Imported animation stretches forearm: " + clip)
				samples += 1
		print("FOREARM_CLIP_PASS clip=%s duration=%f" % [clip, animation.length])
	print("FOREARM_ASSET_PASS rest=%s samples=%d max_error_m=%.8f" % [lengths, samples, max_error])
	quit()
