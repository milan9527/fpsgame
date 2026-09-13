extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func require(condition: bool, message: String) -> bool:
	# Explicit checks also execute in Windows release builds, unlike assert().
	if not condition:
		push_error(message)
		quit(1)
	return condition

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	await process_frame
	if not require(OS.get_name() == "Windows", "Expected the Windows executable"):
		return
	var expected := OS.get_environment("EXPECTED_API")
	if not require(game.api_url == expected and game.ui.endpoint.text == expected,
			"Fresh Windows menu must default to the deployed HTTPS API"):
		return
	var mode := OS.get_environment("WINDOWS_TEST_MODE")
	if mode in ["solo", "duo"]:
		game.start_solo(mode)
		await create_timer(2).timeout
		if not require(game.running and not game.online and game.actors.size() == 16
				and game.phase == "live" and game.match_mode == mode,
				"Offline Windows operation did not start"):
			return
		var file := FileAccess.open("user://windows-runtime-check.txt", FileAccess.WRITE)
		if not require(file != null, "Windows player data must be writable"):
			return
		file.store_string("windows storage check")
		file.close()
		if not require(FileAccess.get_file_as_string("user://windows-runtime-check.txt") ==
				"windows storage check", "Windows player data roundtrip failed"):
			return
		DirAccess.remove_absolute("user://windows-runtime-check.txt")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(
			OS.get_environment("CAPTURE_ARTIFACT_DIR").path_join("windows-" + mode + ".png"))
		if not require(result == OK, "Windows screenshot failed"):
			return
	print("WINDOWS_RUNTIME_PASS mode=", mode, " platform=Windows default_api=ok storage=ok")
	game.request_quit()
