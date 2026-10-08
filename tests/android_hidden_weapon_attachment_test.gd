extends SceneTree

class ObservedGun extends Node3D:
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var actor = load("res://scripts/actor.gd").new()
	actor.mobile_animation = true
	host.add_child(actor)
	assert(actor.character_animation.available)
	assert(actor.third_person_magazine != null)
	var skeleton: Skeleton3D = actor.character_animation.skeleton
	var original := skeleton.get_bone_pose_position(actor.weapon_bone)
	for reason in ["downed", "death", "seated"]:
		actor.downed = reason == "downed"
		actor.character_animation.active_clip = "DownedDeath" if reason == "death" else "Idle"
		if reason == "seated":
			actor.vehicle_ref = weakref(host)
			actor.vehicle_seat = 0
		var before: Transform3D = actor.third_person_gun.transform
		var magazine_before: Transform3D = actor.third_person_magazine.transform
		skeleton.set_bone_pose_position(actor.weapon_bone, original + Vector3(0.1, 0.2, 0.3))
		actor.update_weapon_attachment()
		assert(not actor.third_person_gun.visible)
		assert(actor.third_person_gun.transform == before)
		assert(actor.third_person_magazine.transform == magazine_before)
		actor.downed = false
		actor.vehicle_ref = null
		actor.vehicle_seat = -1
		actor.character_animation.active_clip = "Reload"
		actor.reload_left = actor.RELOAD[actor.weapon] * 0.5
		actor.update_weapon_attachment()
		assert(actor.third_person_gun.visible)
		var expected: Transform3D = skeleton.get_bone_global_pose(actor.weapon_bone) * actor.weapon_rest_offset
		assert(actor.third_person_gun.transform.is_equal_approx(expected))
		assert(not actor.third_person_magazine.transform.is_equal_approx(actor.third_person_magazine_rest))
		actor.reload_left = 0.0
		skeleton.set_bone_pose_position(actor.weapon_bone, original)
		actor.update_weapon_attachment()
		assert(actor.third_person_magazine.transform.is_equal_approx(actor.third_person_magazine_rest))
	var observed := ObservedGun.new()
	actor.third_person_gun.get_parent().add_child(observed)
	observed.transform = actor.third_person_gun.transform
	actor.third_person_gun = observed
	actor.third_person_magazine = null
	observed.set_notify_local_transform(true)
	for i in range(120):
		actor.update_weapon_attachment()
	assert(observed.changes == 0, "Stable socket must not dirty weapon hierarchy")
	skeleton.set_bone_pose_position(actor.weapon_bone, original + Vector3(0.00001, 0, 0))
	actor.update_weapon_attachment()
	assert(observed.changes > 0, "Small animated socket changes must still propagate")
	assert(observed.transform == skeleton.get_bone_global_pose(actor.weapon_bone) * actor.weapon_rest_offset)
	print("PASS hidden weapon: seated/downed/death skip transforms; visible socket and interrupted reload recover; stable socket notifications=0; small motion preserved")
	host.queue_free()
	await process_frame
	quit()
