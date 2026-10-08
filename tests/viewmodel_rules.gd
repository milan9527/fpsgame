extends SceneTree

var game
var actor
var capture := false

func _initialize() -> void:
	call_deferred("run")

func pose(name: String, ads := false) -> void:
	for frame in range(24):
		actor.render_frame(1.0 / 60, false, true, ads)
		if game != null:
			game.ui.sight_aiming = actor.first_person.aim_blend > 0.5
			game.ui.update_hud(actor, game.alive_count(), "live", 300, 110, [], "")
		await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/first-person-" + name + ".png")

func run() -> void:
	capture = "--capture-viewmodel" in OS.get_cmdline_user_args()
	if "--mobile-character" in OS.get_cmdline_user_args():
		var scene := Node3D.new()
		root.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.19, 0.23, 0.28)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.85, 0.9, 1.0)
		environment.environment.ambient_light_energy = 0.7
		scene.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -25, 0)
		light.light_energy = 1.6
		scene.add_child(light)
		actor = load("res://scripts/actor.gd").new()
		actor.mobile_animation = true
		scene.add_child(actor)
		actor.set_local()
		await process_frame
	else:
		game = load("res://scripts/game.gd").new()
		root.add_child(game)
		game.local_profile = null # This fixture must not modify the player's local results.
		await process_frame
		game.start_solo()
		game.set_physics_process(false)
		game.set_process(false)
		actor = game.actors[1]
	actor.position = Vector3(0, 0.01, 20)
	actor.yaw = 0
	actor.pitch = 0
	actor.velocity = Vector3.ZERO
	if game != null: game.sound.volume = 0
	var arms = actor.first_person
	assert(arms.available and arms.skeleton.get_bone_count() == 7)
	for bone_name in ["Root", "UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R", "Forearm.R", "Hand.R"]:
		assert(arms.skeleton.find_bone(bone_name) >= 0, "Articulated arm rig requires " + bone_name)
	assert(arms.clips.size() == 4 and arms.magazine != null)
	if game != null:
		assert(game.actors[-1].first_person.model == null, "Remote actors do not allocate first-person arms")
	var left: int = arms.skeleton.find_bone("Hand.L")
	var right: int = arms.skeleton.find_bone("Hand.R")
	await pose("hip")
	var skin: MeshInstance3D = arms.model.find_children("*", "MeshInstance3D", true, false)[0]
	var rest_vertices := PackedVector3Array()
	if capture:
		rest_vertices = skin.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var left_rest: Vector3 = arms.skeleton.get_bone_global_pose(left).origin
	var right_rest: Vector3 = arms.skeleton.get_bone_global_pose(right).origin
	assert(arms.active_clip == "Hold")
	await pose("aim", true)
	var optic: Vector3 = actor.camera.to_local(actor.gun.to_global(arms.SIGHT))
	assert(absf(optic.x) < 0.001 and absf(optic.y) < 0.001, "Optic center aligns with camera sight line")
	assert(arms.aim_blend == 1 and actor.camera.fov < 49)
	var ammunition: int = actor.total_ammunition()
	for weapon in range(3):
		actor.weapon = weapon
		actor.reload_left = actor.RELOAD[weapon] * 0.5
		await pose("reload" if weapon == 0 else "reload-" + str(weapon))
		assert(arms.active_clip == "Reload" and arms.aim_blend == 0)
		assert(arms.skeleton.get_bone_global_pose(left).origin.distance_to(left_rest) > 0.2)
		# The shortened withdrawal must still visibly separate the magazine.
		# Detailed rendered hand contact throughout extraction is checked by reload_contact_rules.
		assert(arms.magazine.position.distance_to(arms.magazine_rest) > 0.18,
			"Reload visibly separates the magazine from its seated position")
		assert(actor.total_ammunition() == ammunition, "Animation cannot transfer ammunition")
		if capture:
			var animated_vertices: PackedVector3Array = skin.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var displacement := 0.0
			for i in range(rest_vertices.size()):
				displacement = maxf(displacement, rest_vertices[i].distance_to(animated_vertices[i]))
			assert(displacement > 0.15, "Rendered sleeve skin follows animated bones")
	actor.reload_left = 0
	actor.throw_left = 0.7
	await pose("throw")
	assert(arms.active_clip == "Throw" and not actor.gun_model.visible and not arms.sight_dot.visible)
	assert(arms.skeleton.get_bone_global_pose(right).origin.distance_to(right_rest) > 0.3)
	assert(actor.grenades == 2, "Visual throw never consumes inventory")
	actor.throw_left = 0
	actor.heal_left = 1.75
	await pose("heal")
	assert(arms.active_clip == "Heal" and not actor.gun_model.visible)
	assert(actor.medkits == 2 and actor.health == 100)
	actor.heal_left = 0
	await pose("restored")
	assert(arms.active_clip == "Hold" and actor.gun_model.visible)
	assert(not arms.sight_dot.visible, "HUD owns the ballistic reticle; the animated weapon dot stays hidden")
	assert(arms.magazine.position.is_equal_approx(arms.magazine_rest))
	assert(arms.skeleton.get_bone_global_pose(left).origin.distance_to(left_rest) < 0.001)
	actor.apply_damage(10000)
	actor.render_frame(1.0 / 60, false, true, false)
	assert(not actor.gun.visible, "Death hides weapon and arms together")
	print("VIEWMODEL_RULES_PASS rig=ok skin=%s optic_alignment=ok reload_durations=ok throw=ok heal=ok inventory_unchanged=ok reset=ok death=ok" % ("rendered" if capture else "headless"))
	if game != null: game.queue_free()
	await process_frame
	quit()
