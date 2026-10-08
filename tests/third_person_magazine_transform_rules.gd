extends SceneTree

class ObservedNode extends Node3D:
	var changes := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

func _initialize() -> void:
	call_deferred("run")

func legacy_update(actor) -> void:
	var magazine: Node3D = actor.third_person_magazine
	magazine.transform = actor.third_person_magazine_rest
	if actor.reload_left <= 0 or not actor.character_animation.active_clip.ends_with("Reload"):
		return
	var progress := clampf(1.0 - actor.reload_left / actor.RELOAD[actor.weapon], 0.0, 1.0)
	var withdrawal := smoothstep(0.18, 0.40, progress) * (1.0 - smoothstep(0.55, 0.73, progress))
	var parent := magazine.get_parent() as Node3D
	magazine.position += parent.global_basis.inverse() * actor.third_person_gun.global_basis * Vector3(-0.305, -0.23, 0.11) * withdrawal

func run() -> void:
	var actor = load("res://scripts/actor.gd").new()
	actor.mobile_animation = true
	root.add_child(actor)
	await process_frame
	assert(actor.third_person_magazine != null)
	var observed: ObservedNode
	var samples := 0
	var old_changes := 0
	var new_changes := 0
	# Use the real imported weapon hierarchy, with rotating/scaled ancestors.
	for weapon in range(3):
		actor.weapon = weapon
		actor.update_weapon_visuals()
		observed = ObservedNode.new()
		actor.third_person_magazine.get_parent().add_child(observed)
		observed.set_notify_local_transform(true)
		actor.third_person_magazine = observed
		for clip in ["Reload", "CrouchReload", "Idle", "Death"]:
			actor.character_animation.active_clip = clip
			for i in range(121):
				actor.rotation = Vector3(0.1, float(i) * 0.013, -0.2)
				actor.scale = Vector3(1.1, 0.9, 1.2)
				actor.reload_left = actor.RELOAD[weapon] * (1.0 - float(i) / 120.0)
				var initial := observed.transform
				observed.changes = 0
				legacy_update(actor)
				var expected := observed.transform
				old_changes += observed.changes
				observed.transform = initial
				observed.changes = 0
				actor.update_third_person_magazine()
				new_changes += observed.changes
				assert(observed.transform.is_equal_approx(expected), "Reload socket trajectory changed")
				samples += 1
	actor.reload_left = 0
	actor.update_third_person_magazine()
	observed.changes = 0
	for i in range(120):
		actor.update_third_person_magazine()
	assert(observed.changes == 0, "Idle socket must not dirty hierarchy")
	actor.character_animation.active_clip = "Reload"
	actor.reload_left = actor.RELOAD[actor.weapon] * 0.5
	actor.update_third_person_magazine()
	assert(not observed.transform.is_equal_approx(actor.third_person_magazine_rest))
	actor.character_animation.active_clip = "Death"
	actor.update_third_person_magazine()
	assert(observed.transform == actor.third_person_magazine_rest, "Interrupted reload must restore socket")
	observed.position += Vector3.ONE
	actor.reload_left = 0
	actor.update_third_person_magazine()
	assert(observed.transform == actor.third_person_magazine_rest, "External pose must be restored")
	assert(new_changes < old_changes)
	print("MAGAZINE_TRANSFORM_PASS samples=", samples, " old_notifications=", old_changes,
		" new_notifications=", new_changes, " idle_notifications=0 interruption=ok external_reset=ok")
	actor.queue_free()
	await process_frame
	quit()
