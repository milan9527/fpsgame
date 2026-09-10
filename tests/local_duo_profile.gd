extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var directory := OS.get_environment("LOCAL_TEST_ROOT")
	assert(directory != "")
	var Profile = load("res://scripts/local_profile.gd")
	var profile = Profile.new(directory)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = profile
	game.sound.volume = 0
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var legacy := {"id": game.uuid4(), "finished_at": 1800000000, "status": "completed", "rank": 1, "kills": 2, "seconds": 42, "map": "ash_valley"}
	assert(profile.store(legacy))
	var original := FileAccess.get_file_as_string(directory.path_join("records").path_join(legacy.id).path_join("result.json"))
	assert(JSON.parse_string(original).version == 1)
	var conflict := legacy.duplicate()
	conflict.merge({"mode": "duo", "team_id": 1})
	assert(not profile.store(conflict), "Mode cannot be changed under an existing operation ID")
	assert(FileAccess.get_file_as_string(directory.path_join("records").path_join(legacy.id).path_join("result.json")) == original)
	game.start_solo("duo")
	game.elapsed = 80
	game.damage(game.actors[1], 10000, -2, true, false, "FIXTURE", null, true, true)
	assert(game.actors[1].rank == 0)
	for actor in game.actors.values():
		if actor.team_id != 1:
			game.damage(actor, 10000, -1, true, false, "FIXTURE", null, true, true)
	game.finish_round()
	assert(game.local_outbox.is_empty())
	var won_id: String = game.match_id
	game.leave()
	var reopened = Profile.new(directory)
	var saved: Dictionary = reopened.read_record(won_id).record
	assert(saved.mode == "duo" and saved.team_id == 1 and saved.rank == 1 and saved.status == "completed")
	assert(reopened.store(saved), "Exact retry remains idempotent")
	assert(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("records").path_join(won_id).path_join("result.json"))).version == 2)
	var summary: Dictionary = reopened.summary()
	assert(summary.modes.solo.wins == 1 and summary.modes.duo.wins == 1)
	assert(summary.completed == 2 and summary.wins == 2)
	# Leaving while the teammate can still win is abandonment, not placement zero completion.
	game.start_solo("duo")
	game.elapsed = 40
	game.damage(game.actors[1], 10000, -2, true, false, "FIXTURE", null, true, true)
	var abandoned_id: String = game.match_id
	game.leave()
	saved = reopened.read_record(abandoned_id).record
	assert(saved.status == "abandoned" and saved.rank == 0 and saved.mode == "duo")
	# A wiped team has a final placement even while other teams are fighting.
	game.start_solo("duo")
	game.elapsed = 40
	game.damage(game.actors[1], 10000, -2, true)
	game.damage(game.actors[-1], 10000, -2, true)
	game.rescue.update(game, 0)
	var wiped_id: String = game.match_id
	game.leave()
	saved = reopened.read_record(wiped_id).record
	assert(saved.status == "completed" and saved.rank == 8 and saved.mode == "duo")
	for invalid in [dict_with(saved, "team_id", 0), dict_with(saved, "team_id", true), dict_with(saved, "rank", 9), dict_with(saved, "mode", "squad")]:
		assert(not profile.valid_record(invalid))
	var incomplete := saved.duplicate()
	incomplete.erase("team_id")
	assert(not profile.valid_record(incomplete))
	# Failed duo publication stays pending and uses the same immutable ID on retry.
	var blocked_path := directory.path_join("blocked")
	var file := FileAccess.open(blocked_path, FileAccess.WRITE)
	file.store_string("fixture")
	file.close()
	game.local_profile = Profile.new(blocked_path)
	game.start_solo("duo")
	game.finish_round()
	assert(game.local_outbox.size() == 1 and game.local_outbox[0].mode == "duo")
	game.local_profile = reopened
	game.show_local_history()
	assert(game.local_outbox.is_empty())
	assert("DUO" in game.ui.local_summary_label.text and game.ui.local_history_grid.columns == 5)
	summary = reopened.summary()
	assert(summary.records.size() == 5 and summary.modes.solo.completed == 1 and summary.modes.duo.completed == 3 and summary.modes.duo.abandoned == 1)
	if "--capture-local" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("LOCAL_CAPTURE_PATH")) == OK)
	print("LOCAL_DUO_PROFILE_PASS legacy=ok version2=ok dead_teammate_victory=ok abandonment=ok team_elimination=ok mode_stats=ok immutable=ok retry=ok history=ok")
	game.request_quit()

func dict_with(record: Dictionary, key: String, value) -> Dictionary:
	var copy := record.duplicate()
	copy[key] = value
	return copy
