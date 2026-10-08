extends SceneTree

# Reproducible review frames; image generation is not an alignment assertion.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(not output.is_empty())
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	var actor = game.actors[game.local_id]
	actor.position = Vector3(17, 0.05, 50)
	actor.yaw = atan2(-18, 16)
	actor.pitch = -0.03
	var preview_pair := "--review-carbine-pair" in OS.get_cmdline_user_args()
	var aim_pairs := "--review-aim-pairs" in OS.get_cmdline_user_args()
	var selected_weapon := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-weapon="):
			selected_weapon = argument.trim_prefix("--review-weapon=").to_int()
			assert(selected_weapon >= 0 and selected_weapon < 3)
	var frame_count := 0
	for weapon in range(1 if preview_pair else 3):
		if selected_weapon >= 0 and weapon != selected_weapon:
			continue
		actor.reload_left = 0.0
		actor.switch_weapon(weapon)
		for pose in ["hip", "ads", "reload-quarter", "reload-half", "reload-three-quarter"]:
			if (preview_pair or aim_pairs) and pose.begins_with("reload"):
				continue
			actor.reload_left = 0.0
			if pose.begins_with("reload"):
				var remaining := 0.5
				if pose == "reload-quarter": remaining = 0.75
				if pose == "reload-three-quarter": remaining = 0.25
				actor.reload_left = actor.RELOAD[weapon] * remaining
			for frame in range(90):
				actor.render_frame(1.0 / 60.0, false, true, pose == "ads")
			game.ui.sight_aiming = pose == "ads"
			game.ui.update_hud(actor, 16, "live", 300, 110, [], "")
			for frame in range(4): await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(
				output.path_join("weapon-%d-%s.png" % [weapon, pose])) == OK)
			frame_count += 1
	print("WEAPON_REVIEW_CAPTURE_PASS frames=%d; visual inspection required" % frame_count)
	quit()
