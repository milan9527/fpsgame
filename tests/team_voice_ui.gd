extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	assert(not game.ui.voice_microphone and not game.team_voice.microphone.player.playing)
	assert(game.ui.controls.rows.has("push_to_talk"))
	game.start_solo()
	game.ui.voice_microphone = true
	Input.action_press("push_to_talk")
	await process_frame
	await process_frame
	assert(not game.team_voice.microphone.transmitting, "Offline PTT cannot open microphone")
	Input.action_release("push_to_talk")
	game.ui.voice_microphone = false
	game.ui.set_pause(true)
	await process_frame
	await process_frame
	assert(game.ui.pause_panel.get_global_rect().end.y < 900, "Voice controls must fit the field menu")
	get_root().get_texture().get_image().save_png("res://../artifacts/team-voice-settings.png")
	game.ui.voice_setup.open()
	await process_frame
	assert(game.ui.voice_setup.devices.item_count >= 1)
	assert(not game.ui.voice_setup.testing)
	assert(game.ui.voice_setup.get_global_rect().end.y < 900)
	game.ui.voice_setup.update_level(0.4, false, true, Time.get_ticks_msec())
	assert(game.ui.voice_setup.meter.value == 40 and "Input detected" in game.ui.voice_setup.status.text)
	game.ui.voice_setup.update_level(1.0, true, true, Time.get_ticks_msec())
	assert("clipping" in game.ui.voice_setup.status.text)
	game.ui.voice_setup.update_level(0, false, true, 0)
	assert("No input detected" in game.ui.voice_setup.status.text)
	await process_frame
	get_root().get_texture().get_image().save_png("res://../artifacts/microphone-setup.png")
	game.ui.voice_setup.testing = true
	game.ui.voice_setup.close()
	assert(not game.ui.voice_setup.testing)
	game.ui.voice_setup.open()
	game.leave()
	await process_frame
	assert(game.team_voice.receiver.streams.is_empty())
	assert(not game.team_voice.microphone.player.playing)
	assert(not game.ui.voice_setup.visible)
	game.queue_free()
	await process_frame
	print("TEAM_VOICE_UI_PASS microphone_default_off=ok offline_ptt_blocked=ok rebind_row=ok field_menu_bounds=ok leave_cleanup=ok")
	quit()
