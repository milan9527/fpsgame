extends SceneTree
const Bindings = preload("res://scripts/control_bindings.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "user://qa-bindings-%d.cfg" % Time.get_ticks_usec()
	var profile = Bindings.new(path)
	profile.load_profile()
	assert(profile.keys == Bindings.DEFAULTS)
	profile.apply()
	assert(not profile.bind("reload", KEY_W) and profile.keys.reload == KEY_R)
	assert(not profile.bind("reload", KEY_ESCAPE))
	assert(not profile.bind("pause", KEY_F))
	assert(not profile.bind("spectate_next", KEY_T), "Voice key also applies while spectating")
	assert(not profile.bind("push_to_talk", KEY_E))
	assert(profile.bind("reload", KEY_F))
	var fresh = Bindings.new(path)
	fresh.load_profile()
	assert(fresh.keys.reload == KEY_F and fresh.keys.spectate_next == KEY_E)
	fresh.apply()
	assert(InputMap.action_get_events("reload")[0].physical_keycode == KEY_F)
	var failed = Bindings.new("user://nonexistent-bindings-folder/profile.cfg")
	assert(not failed.bind("reload", KEY_Y) and failed.keys.reload == KEY_R)
	assert(InputMap.action_get_events("reload")[0].physical_keycode == KEY_F, "Failed save does not alter live map")
	var invalid := ConfigFile.new()
	invalid.set_value("keyboard", "reload", KEY_W)
	invalid.save(path)
	fresh = Bindings.new(path)
	fresh.load_profile()
	assert(fresh.keys == Bindings.DEFAULTS and fresh.message != "")
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.bindings.path = path
	game.bindings.keys = Bindings.DEFAULTS.duplicate()
	game.bindings.apply()
	game.start_solo()
	game.ui.set_pause(true)
	game.ui.controls.open()
	game.ui.controls.rows.reload.pressed.emit()
	var key := InputEventKey.new()
	key.keycode = KEY_Y
	key.physical_keycode = KEY_Y
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	await process_frame
	assert(game.bindings.keys.reload == KEY_Y and game.ui.controls.pending == "")
	assert(game.ui.controls.visible and paused)
	var actor = game.actors[1]
	assert(not game.local_command(actor).reload and not game.local_command(actor).fire)
	game.ui.controls.rows.loot.pressed.emit()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(key.duplicate())
	await process_frame
	assert(game.ui.controls.pending == "" and game.ui.controls.visible)
	key.pressed = false
	Input.parse_input_event(key.duplicate())
	key.pressed = true
	Input.parse_input_event(key.duplicate())
	await process_frame
	assert(not game.ui.controls.visible and game.ui.pause_panel.visible and paused)
	assert(game.bindings.reset_defaults())
	assert(game.bindings.keys == Bindings.DEFAULTS)
	if "--capture-bindings" in OS.get_cmdline_user_args():
		game.ui.controls.open()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/controls.png")
	game.ui.set_pause(false)
	DirAccess.remove_absolute(path)
	game.queue_free()
	await process_frame
	print("BINDINGS_RULES_PASS remap=ok persistence=ok conflict=ok reserved_escape=ok corrupt_fallback=ok save_failure=ok capture=ok pause=ok neutral_input=ok reset=ok")
	quit()
