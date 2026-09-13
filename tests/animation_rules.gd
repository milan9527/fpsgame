extends SceneTree

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Animation skin verification requires a rendering server; use xvfb-run")
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null # This fixture must not modify the player's local results.
	await process_frame
	game.start_solo()
	game.running = false
	await process_frame
	await process_frame
	var actor = game.actors[1]
	var animation = actor.character_animation
	assert(animation.available, "Imported model must contain real animation and skeleton")
	print("IMPORTED_CLIPS ", animation.clips.keys(), " bones=", animation.skeleton.get_bone_count())
	for name in ["Idle", "Walk", "Run", "CrouchIdle", "CrouchWalk", "CrouchReload", "Jump", "Reload", "Death"]:
		assert(animation.clips.has(name), "Missing animation: " + name)
	actor.grounded = true
	actor.velocity = Vector3.ZERO
	actor.pitch = 0
	animation.update(actor, 0.01)
	var skeleton: Skeleton3D = animation.skeleton
	var head := skeleton.find_bone("Head")
	var shin := skeleton.find_bone("Shin.L")
	var foot := skeleton.find_bone("Foot.L")
	assert(head >= 0 and shin >= 0 and foot >= 0)
	var meshes: Array = actor.body_mesh.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return mesh.skin != null)
	assert(meshes.size() == 1, "Character mesh is merged for bounded draw submissions")
	var skin: MeshInstance3D = meshes[0]
	assert(skin.skin != null and skin.mesh.get_surface_count() == 4)
	# Joining differently named Blender UV layers previously left sleeves and
	# trousers sampling one camouflage texel despite the texture being present.
	var cloth_triangles := 0
	var mapped_triangles := 0
	for surface in range(skin.mesh.get_surface_count()):
		var material = skin.mesh.surface_get_material(surface)
		if material.resource_name != "Ranger / field uniform": continue
		var arrays: Array = skin.mesh.surface_get_arrays(surface)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert(not uv.is_empty() and not indices.is_empty(), "Clothing requires primary UVs")
		for index in range(0, indices.size(), 3):
			var edge_a := uv[indices[index + 1]] - uv[indices[index]]
			var edge_b := uv[indices[index + 2]] - uv[indices[index]]
			cloth_triangles += 1
			if absf(edge_a.cross(edge_b)) > 0.0000001: mapped_triangles += 1
	print("CLOTH_UV_COVERAGE ", mapped_triangles, "/", cloth_triangles)
	assert(cloth_triangles > 0 and mapped_triangles > cloth_triangles * 0.9, "Camouflage UVs must cover the actual cloth triangles")
	skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw
	var standing_bounds := skin.bake_mesh_from_current_skeleton_pose().get_aabb()
	var standing_head := skeleton.get_bone_global_pose(head).origin
	var standing_foot := skeleton.get_bone_global_pose(foot).origin
	actor.crouch = true
	actor.update_stance()
	animation.update(actor, 0.01)
	skeleton.force_update_all_bone_transforms()
	await RenderingServer.frame_post_draw
	var crouched_bounds := skin.bake_mesh_from_current_skeleton_pose().get_aabb()
	print("SKIN_BOUNDS ", standing_bounds, " -> ", crouched_bounds)
	assert(standing_bounds.end.y - crouched_bounds.end.y > 0.55, "Weighted vertices follow the crouch bones")
	assert(absf(standing_bounds.position.y - crouched_bounds.position.y) < 0.035, "Skinned boots retain ground contact")
	var crouched_head := skeleton.get_bone_global_pose(head).origin
	var crouched_foot := skeleton.get_bone_global_pose(foot).origin
	print("POSE_HEIGHT stand=", standing_head, " crouch=", crouched_head, " feet=", standing_foot, " -> ", crouched_foot)
	assert(standing_head.y - crouched_head.y > 0.55, "Skeleton head really lowers in crouch")
	assert(absf(crouched_foot.y - standing_foot.y) < 0.035, "Crouching retains foot contact")
	assert(actor.body_mesh.scale == Vector3.ONE, "Crouch must not squash the mesh")
	actor.crouch = false
	actor.update_stance()
	actor.velocity = Vector3(0, 0, -4.5)
	animation.update(actor, 0.2)
	var pose_a := skeleton.get_bone_global_pose(shin)
	animation.update(actor, 0.25)
	var pose_b := skeleton.get_bone_global_pose(shin)
	assert(not pose_a.is_equal_approx(pose_b), "Walking must animate leg joints")
	assert(animation.active_clip == "Walk")
	actor.velocity.z = -9
	animation.update(actor, 0.1)
	assert(animation.active_clip == "Run")
	actor.velocity = Vector3.ZERO
	actor.reload_left = 1.5
	animation.update(actor, 0.1)
	assert(animation.active_clip == "Reload")
	actor.crouch = true
	actor.update_stance()
	animation.update(actor, 0.1)
	assert(animation.active_clip == "CrouchReload", "Reload must preserve crouched pose")
	actor.reload_left = 0
	actor.crouch = false
	actor.update_stance()
	actor.grounded = false
	animation.update(actor, 0.1)
	assert(animation.active_clip == "Jump")
	actor.apply_damage(10000)
	animation.update(actor, 0.6)
	animation.update(actor, 0.6)
	assert(animation.active_clip == "Death" and actor.body_mesh.rotation.z == 0, "Death uses the skeleton, not whole-mesh tipping")
	var death_head := skeleton.get_bone_global_pose(head).origin
	assert(death_head.y < 0.5, "Death must bring head near ground")
	print("ANIMATION_RULES_PASS skin=ok crouch=ok feet=ok walk=ok run=ok reload=ok jump=ok death=ok")
	quit()
