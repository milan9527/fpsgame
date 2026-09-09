extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory := OS.get_environment("LOCAL_TEST_ROOT")
	assert(directory != "", "This test requires an isolated result directory")
	var Profile = load("res://scripts/local_profile.gd")
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = Profile.new(directory)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.volume = 0
	game.start_solo()
	game.elapsed = 123
	for actor in game.actors.values():
		if actor.actor_id != 1:
			game.damage(actor, 10000, 1, true)
	game.finish_round()
	game.finish_round()
	assert(game.local_outbox.is_empty())
	game._process(1.0 / 60)
	assert("LOCAL RESULT SAVED" in game.ui.result_label.text)
	game.leave()
	game.ui.local_history_requested.emit()
	assert(game.ui.local_history_panel.visible)
	var summary: Dictionary = Profile.new(directory).summary()
	assert(summary.completed == 1 and summary.wins == 1 and summary.kills == 15)
	assert("1 COMPLETED" in game.ui.local_summary_label.text)
	game.start_solo()
	assert(not game.ui.local_history_panel.visible, "Deployment closes local history")
	game.elapsed = 45
	game.leave()
	summary = game.local_profile.summary()
	assert(summary.abandoned == 1 and summary.completed == 1 and summary.wins == 1)
	game.start_solo()
	game.elapsed = 90
	game.damage(game.actors[1], 10000, -1, true)
	game.leave()
	summary = game.local_profile.summary()
	assert(summary.completed == 2 and summary.abandoned == 1)
	# Failed publication remains in memory; closing the game shows a retry choice.
	var blocked_path := directory.path_join("not-a-directory")
	var blocked := FileAccess.open(blocked_path, FileAccess.WRITE)
	blocked.store_string("fixture")
	blocked.close()
	game.local_profile = Profile.new(blocked_path)
	game.start_solo()
	game.finish_round()
	assert(game.local_outbox.size() == 1)
	game.request_quit()
	assert(not game.shutdown_requested and not game.running)
	assert(game.ui.local_history_panel.visible and game.ui.local_exit_button.visible)
	assert("not saved" in game.ui.local_warning_label.text)
	game.local_profile = Profile.new(directory)
	game.ui.local_history_requested.emit()
	assert(game.local_outbox.is_empty() and not game.ui.local_exit_button.visible)
	summary = game.local_profile.summary()
	assert(summary.completed == 3 and summary.abandoned == 1 and summary.records.size() == 4)
	assert(game.ui.local_warning_label.text == "")
	# Online state is never recorded into the offline ledger.
	game.start_solo()
	game.online = true
	game.save_local_operation()
	game.finish_round()
	assert(game.local_profile.summary().records.size() == 4)
	game.leave()
	game.show_local_history()
	assert(game.ui.local_history_backdrop.visible)
	assert(game.ui.status.text == "Local history loaded.")
	if "--capture-local" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OS.get_environment("LOCAL_CAPTURE_PATH")) == OK)
	print("LOCAL_PROFILE_UI_PASS finished=ok idempotent=ok abandoned=ok eliminated=ok save_failure=visible retry=ok quit_guard=ok online_separation=ok history=ok")
	game.request_quit()
