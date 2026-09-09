extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var capture := "--capture-weapons" in OS.get_cmdline_user_args()
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.volume = 0
	for other in game.actors.values():
		other.position = Vector3(105, 0.02, 80 + other.actor_id)
	var actor = game.actors[1]
	var remote = game.actors[-1]
	actor.position = Vector3(0, 0.02, 20)
	actor.yaw = 0
	actor.pitch = 0
	actor.grounded = true
	remote.position = Vector3(-1.2, 0.02, 17)
	remote.target_position = remote.position
	remote.yaw = -PI / 2
	remote.grounded = true
	var muzzle_positions := []
	for weapon in range(3):
		actor.switch_weapon(weapon)
		var state: Dictionary = remote.pack()
		state.w = weapon
		remote.unpack(state, false)
		for ads in [false, true]:
			for frame in range(30):
				actor.render_frame(1.0 / 60, false, true, ads)
				remote.render_frame(1.0 / 60, true, false, false)
				game.ui.sight_aiming = ads
				game.ui.update_hud(actor, game.alive_count(), "live", 300, 110, [], "")
				await process_frame
			assert(actor.gun_model.scene_file_path == actor.WEAPON_MODELS[weapon])
			assert(remote.third_person_gun.scene_file_path == actor.WEAPON_MODELS[weapon])
			assert(remote.gun_model == null and remote.first_person.model == null, "Remote actors allocate no hidden first-person gun")
			assert(actor.gun_model.find_children("*", "MeshInstance3D", true, false).size() == 4, "Static parts are merged; magazine and hidden stocks remain separate")
			var sight = actor.gun_model.find_child("SightAnchor", true, false)
			var muzzle = actor.gun_model.find_child("MuzzleAnchor", true, false)
			assert(sight != null and muzzle != null)
			assert(actor.muzzle.global_position.distance_to(muzzle.global_position) < 0.001)
			assert(actor.muzzle.position.distance_to(actor.BARREL_ENDS[weapon]) < 0.001, "Authority barrel probe matches Blender anchor")
			assert(is_equal_approx(actor.first_person.sight_position.y, actor.OPTIC_HEIGHTS[weapon]))
			if ads:
				var eye_sight: Vector3 = actor.camera.to_local(sight.global_position)
				assert(absf(eye_sight.x) < 0.001 and absf(eye_sight.y) < 0.001, "Each weapon's own optic aligns")
				assert(absf(actor.camera.fov - actor.AIM_FOV[weapon]) < 0.1)
			else:
				muzzle_positions.append(actor.muzzle.position.z)
			if capture:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../artifacts/weapon-%d-%s.png" % [weapon, "aim" if ads else "hip"])
		var standing: Vector3 = remote.third_person_gun.global_position
		remote.crouch = true
		remote.update_stance()
		remote.render_frame(0.02, false, false, false)
		assert(standing.y - remote.third_person_gun.global_position.y > 0.5, "Weapon follows animated crouch bone")
		remote.crouch = false
		remote.update_stance()
		remote.render_frame(0.02, false, false, false)
	assert(muzzle_positions[2] < muzzle_positions[1] and muzzle_positions[1] < muzzle_positions[0], "Distinct barrel lengths drive muzzle effects")
	assert(actor.ammo + actor.reserve == 150, "Weapon switching preserves total ammunition")
	print("WEAPON_VISUALS_RULES_PASS models=3 local=ok remote_snapshot=ok anchors=ok optic_alignment=ok zoom=ok bone_attachment=ok bounded_meshes=ok inventory_unchanged=ok")
	game.queue_free()
	await process_frame
	quit()
