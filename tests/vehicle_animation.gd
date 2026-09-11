extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	scene.add_child(load("res://scripts/world.gd").new())
	var car = load("res://scripts/vehicle.gd").new()
	scene.add_child(car)
	var actors: Array = []
	for index in range(2):
		var actor = load("res://scripts/actor.gd").new()
		scene.add_child(actor)
		# Animation fixture: collision and entry validation have a separate physics test.
		actor.vehicle_ref = weakref(car)
		actor.vehicle_seat = index
		car.seats.slots[index] = {"actor": weakref(actor), "mask": actor.collision_mask, "layer": actor.collision_layer}
		actor.local_view = true
		actor.position = car.seats.ANCHORS[index]
		actor.pitch = 0.8
		actor.recoil = 0.3
		actor.flash_left = 1
		actor.render_frame(0.1, false, true, false)
		assert(actor.character_animation.active_clip == ["SeatedDriver", "SeatedPassenger"][index])
		assert(not actor.gun.visible and not actor.third_person_gun.visible and not actor.muzzle.visible)
		var skeleton: Skeleton3D = actor.character_animation.skeleton
		skeleton.force_update_all_bone_transforms()
		var hip := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
		assert(absf(hip.y - 0.99) < 0.02)
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("Hand.L")).origin
		assert(absf(hand.y - (1.19 if index == 0 else 0.94)) < 0.02)
		assert(absf(hand.z + (0.28 if index == 0 else 0.34)) < 0.02)
		actors.append(actor)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(3, 2.8, -4)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	for actor in actors:
		var meshes: Array = actor.body_mesh.find_children("*", "MeshInstance3D", true, false)
		var skin: MeshInstance3D = meshes.filter(func(mesh): return mesh.skin != null)[0]
		var bounds := skin.bake_mesh_from_current_skeleton_pose().get_aabb()
		print("SEATED_SKIN_BOUNDS ", bounds)
		assert(bounds.position.y > 0.25 and bounds.end.y < 1.8)
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if output.is_empty():
		output = "res://../artifacts"
	assert(root.get_texture().get_image().save_png(output.path_join("vehicle-seated.png")) == OK)
	var driver = actors[0]
	driver.downed = true
	driver.render_frame(0.1, false, true, false)
	assert(driver.character_animation.active_clip == "SeatedDowned")
	driver.alive = false
	driver.render_frame(0.1, false, true, false)
	var animation = driver.character_animation
	var time: float = animation.player.current_animation_position
	driver.render_frame(0.5, false, true, false)
	assert(is_equal_approx(time, animation.player.current_animation_position))
	driver.alive = true
	driver.downed = false
	car.seats.release(driver, driver.global_position)
	driver.grounded = true
	driver.render_frame(0.1, false, true, false)
	assert(animation.active_clip == "Idle" and driver.gun.visible and driver.third_person_gun.visible)
	scene.queue_free()
	await process_frame
	print("VEHICLE_ANIMATION_PASS driver=ok passenger=ok hands=ok bounds=ok weapon_hide=ok downed=ok exit=ok")
	quit()
