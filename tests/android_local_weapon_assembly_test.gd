extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var actor = load("res://scripts/actor.gd").new()
	actor.mobile_animation = true
	host.add_child(actor)
	assert(actor.character_animation.available)
	var world_weapon = actor.third_person_gun
	assert(world_weapon != null and actor.gun_model == null)
	actor.set_local()
	assert(actor.third_person_gun == world_weapon)
	assert(not world_weapon.is_queued_for_deletion())
	assert(actor.gun_model != null and actor.gun.visible)
	assert(actor.camera.current and not actor.body_mesh.visible)
	var first_weapon = actor.gun_model
	actor.update_weapon_visuals()
	assert(actor.gun_model == first_weapon)
	for kind in [2, 1, 0]:
		actor.weapon = kind
		actor.update_weapon_visuals()
		assert(actor.third_person_gun != world_weapon)
		assert(actor.gun_model != first_weapon)
		world_weapon = actor.third_person_gun
		first_weapon = actor.gun_model
		actor.grip_slots[kind] = 1
		actor.update_weapon_visuals()
		assert(actor.third_person_gun != world_weapon)
		assert(actor.gun_model != first_weapon)
		assert(actor.third_person_gun.get_node_or_null("Foregrip") != null)
		assert(actor.gun_model.get_node_or_null("Foregrip") != null)
		world_weapon = actor.third_person_gun
		first_weapon = actor.gun_model
	actor.update_weapon_visuals(true)
	assert(actor.third_person_gun != world_weapon and actor.gun_model != first_weapon)
	print("PASS local weapon assembly: retained world model on local activation; first-person, three weapons, grips and forced refresh")
	host.queue_free()
	await process_frame
	quit()
