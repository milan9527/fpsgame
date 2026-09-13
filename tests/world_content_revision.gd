extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.build_info.content_revision == "ash-valley-19")
	assert(game.compatible_build(game.build_info))
	var previous: Dictionary = game.build_info.duplicate()
	previous.content_revision = "ash-valley-18"
	assert(not game.compatible_build(previous), "Older worlds lack the new roof collision contract")
	game.start_solo()
	var directory := "user://qa-world-revision-%d" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(directory) == OK)
	game.checkpoint.path = directory.path_join("operation.dat")
	var old_state: Dictionary = game.snapshot_solo()
	old_state.content = "ash-valley-18"
	assert(game.checkpoint.save_state(old_state, "ash-valley-18"))
	assert(game.checkpoint.load_state(game.build_info.content_revision).is_empty(), "Do not restore positions into a different collision world")
	assert(not game.checkpoint.load_state("ash-valley-18").is_empty(), "Rejection must preserve the original checkpoint")
	var current: Dictionary = game.snapshot_solo()
	assert(game.checkpoint.save_state(current, game.build_info.content_revision))
	assert(not game.checkpoint.load_state(game.build_info.content_revision).is_empty())
	print("WORLD_CONTENT_REVISION_PASS matching=accepted old_world=rejected old_save=preserved current_save=ok")
	quit()
