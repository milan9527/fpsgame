extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	scene.add_child(load("res://scripts/world.gd").new())
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 1.8, -20.5)
	camera.look_at(Vector3(0, 0.7, -15))
	camera.fov = 56
	camera.current = true
	var actors: Array = []
	for index in range(3):
		var actor = load("res://scripts/actor.gd").new()
		actor.actor_id = index + 1
		actor.position = Vector3((index - 1) * 1.7, 0.02, -15)
		scene.add_child(actor)
		actor.grounded = true
		actor.crouch = index == 0
		actor.downed = index > 0
		actor.velocity = Vector3(0, 0, -1) if index == 2 else Vector3.ZERO
		actor.update_stance()
		actor.render_frame(0.2, false, false, false)
		assert(actor.character_animation.active_clip == ["CrouchIdle", "DownedIdle", "DownedCrawl"][index])
		assert(actor.third_person_gun.visible == (index == 0))
		actors.append(actor)
		var label := Label3D.new()
		label.text = ["CROUCH", "DOWNED / WAIT", "DOWNED / CRAWL"][index]
		label.position = actor.position + Vector3(0, 1.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.pixel_size = 0.0028
		scene.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var down = actors[1]
	var skeleton: Skeleton3D = down.character_animation.skeleton
	skeleton.force_update_all_bone_transforms()
	var skin: MeshInstance3D = down.body_mesh.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return mesh.skin != null)[0]
	var bounds := skin.bake_mesh_from_current_skeleton_pose().get_aabb()
	print("DOWNED_SKIN_BOUNDS ", bounds)
	assert(bounds.end.y < 1.2 and bounds.end.y > 0.65 and bounds.position.y > -0.15)
	var crawl = actors[2]
	var crawl_skeleton: Skeleton3D = crawl.character_animation.skeleton
	var hand := crawl_skeleton.find_bone("Hand.L")
	var before := crawl_skeleton.get_bone_global_pose(hand)
	crawl.render_frame(0.4, false, false, false)
	assert(not before.is_equal_approx(crawl_skeleton.get_bone_global_pose(hand)))
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://../artifacts/downed-animation.png") == OK)
	down.set_local()
	down.render_frame(0.01, false, true, false)
	assert(not down.gun.visible)
	down.downed = false
	down.health = 30
	down.update_stance()
	down.render_frame(0.3, false, true, false)
	assert(down.character_animation.active_clip == "Idle" and down.gun.visible and down.third_person_gun.visible)
	down.alive = false
	down.render_frame(0.2, false, true, false)
	assert(down.character_animation.active_clip == "Death" and not down.gun.visible)
	crawl.alive = false
	crawl.downed = false
	crawl.render_frame(0.9, false, false, false)
	assert(crawl.character_animation.active_clip == "DownedDeath")
	crawl.render_frame(0.1, false, false, false)
	assert(crawl.character_animation.active_clip == "DownedDeath")
	assert(not crawl.third_person_gun.visible)
	crawl_skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw
	var corpse_skin: MeshInstance3D = crawl.body_mesh.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return mesh.skin != null)[0]
	var corpse_bounds := corpse_skin.bake_mesh_from_current_skeleton_pose().get_aabb()
	print("DOWNED_CORPSE_BOUNDS ", corpse_bounds)
	assert(corpse_bounds.end.y < 0.95 and corpse_bounds.position.y > -0.15 and corpse_bounds.position.y < 0.2)
	scene.queue_free()
	await process_frame
	print("DOWNED_ANIMATION_PASS distinct_idle=ok crawl_motion=ok skin_height=ok weapons=ok revive=ok death=ok")
	quit()
