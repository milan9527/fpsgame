extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	var model = load("res://assets/operator.glb").instantiate()
	root.add_child(model)
	var animation = actor.character_animation
	animation.setup(model)
	var skeleton: Skeleton3D = animation.skeleton
	var left := skeleton.find_bone("Hand.L")
	var right := skeleton.find_bone("Hand.R")
	var weapon := skeleton.find_bone("Weapon")
	var results := []
	for crouched in [false, true]:
		for weapon_index in range(3):
			actor.weapon = weapon_index
			actor.crouched = crouched
			actor.grounded = true
			actor.reload_left = 0
			animation.update(actor, 0.2)
			var support: Vector3 = skeleton.get_bone_global_pose(left).origin
			var firing: Vector3 = skeleton.get_bone_global_pose(right).origin
			var attachment: Vector3 = skeleton.get_bone_global_pose(weapon).origin
			var max_travel := 0.0
			var max_firing_drift := 0.0
			var max_weapon_drift := 0.0
			var duration: float = actor.RELOAD[weapon_index]
			for tick in range(int(ceil(duration * 60))):
				actor.reload_left = maxf(0.001, duration - tick / 60.0)
				animation.update(actor, 1.0 / 60.0)
				skeleton.force_update_all_bone_transforms()
				assert(animation.active_clip == ("CrouchReload" if crouched else "Reload"))
				max_travel = maxf(max_travel, support.distance_to(skeleton.get_bone_global_pose(left).origin))
				max_firing_drift = maxf(max_firing_drift, firing.distance_to(skeleton.get_bone_global_pose(right).origin))
				max_weapon_drift = maxf(max_weapon_drift, attachment.distance_to(skeleton.get_bone_global_pose(weapon).origin))
			assert(max_travel > 0.48, "Support hand must visibly reach the belt")
			assert(max_firing_drift < 0.03 and max_weapon_drift < 0.03, "Firing grip and attachment must remain stable")
			assert(support.distance_to(skeleton.get_bone_global_pose(left).origin) < 0.04, "Support grip must recover")
			results.append({"weapon": weapon_index, "crouched": crouched,
				"hand_travel": max_travel, "firing_drift": max_firing_drift,
				"weapon_drift": max_weapon_drift})
	print("RELOAD_POSE_RULES_PASS ", JSON.stringify(results))
	actor.free()
	model.queue_free()
	quit()
