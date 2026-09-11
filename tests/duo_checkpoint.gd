extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var directory := OS.get_environment("CHECKPOINT_TEST_ROOT")
	assert(directory != "")
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = game.LocalProfile.new(directory.path_join("results"))
	game.checkpoint.path = directory.path_join("checkpoint.dat")
	game.sound.volume = 0
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	if "--capture-duo-menu" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/duo-deployment-menu.png") == OK)
	game.ui.duo_requested.emit()
	assert(game.match_mode == "duo" and game.actors.size() == 16)
	game.elapsed = 30
	var player = game.actors[1]
	var ally = game.actors[-1]
	for id in [-14, -15]:
		game.damage(game.actors[id], 10000, -1, true, false, "FIXTURE", null, true, true)
	assert(game.teams.ranks[8] == 8)
	game.damage(player, 10000, -2, true)
	assert(game.rescue.interact(game, ally))
	game.rescue.update(game, 2)
	assert(player.downed and ally.revive_left == 3)
	var before: Dictionary = game.snapshot_solo()
	assert(before.version == 2 and game.checkpoint.validate(before, game.build_info.content_revision))
	var invalid := before.duplicate(true)
	invalid.actors[0].team = 8
	assert(not game.checkpoint.validate(invalid, game.build_info.content_revision))
	invalid = before.duplicate(true)
	invalid.actors[0].knock_attacker = 999
	assert(not game.checkpoint.validate(invalid, game.build_info.content_revision))
	invalid = before.duplicate(true)
	invalid.actors[1].revive_target = -2
	assert(not game.checkpoint.validate(invalid, game.build_info.content_revision))
	var id: String = game.match_id
	assert(game.suspend_solo())
	assert(game.local_profile.summary().records.is_empty())
	assert(game.resume_solo() and game.match_mode == "duo" and paused)
	player = game.actors[1]
	ally = game.actors[-1]
	assert(player.downed and player.knock_attacker == -2 and player.bleed_left == 28)
	assert(ally.revive_target == 1 and ally.revive_left == 3 and game.teams.friendly(1, -1))
	assert(game.match_id == id and game.teams.members.size() == 8)
	assert(game.teams.ranks[8] == 8 and game.actors[-14].rank == 8 and not game.actors[-15].alive)
	game.ui.set_pause(false)
	game.rescue.update(game, 3)
	assert(not player.downed and player.health == 30)
	# A dead local player may suspend while their teammate is still competing.
	game.damage(player, 10000, -2, true)
	game.damage(player, 10000, -2, true)
	game._process(0.016)
	assert(game.spectator.target_id == -1 and game.can_suspend_operation())
	assert(game.suspend_solo() and game.resume_solo())
	assert(not game.actors[1].alive and game.spectator.target_id == -1)
	assert(game.local_profile.summary().records.is_empty())
	game.ui.set_pause(false)
	for actor in game.actors.values():
		if actor.team_id != game.actors[1].team_id:
			game.damage(actor, 10000, -1, true, false, "FIXTURE", null, true, true)
	game.finish_round()
	assert(game.actors[1].rank == 1)
	game.leave()
	assert(not game.resume_solo(), "Completed team checkpoint cannot roll back a recorded victory")
	var result: Dictionary = game.local_profile.read_record(id).record
	assert(result.mode == "duo" and result.rank == 1)
	for frame in range(3):
		await process_frame
	print("DUO_CHECKPOINT_PASS downed=ok attribution=ok revive_progress=ok teams=ok spectator=ok no_abandon=ok victory=ok finalized_guard=ok invalid_state=blocked")
	game.request_quit()
