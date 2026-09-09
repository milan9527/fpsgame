extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.elapsed = 10
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	for other in game.actors.values():
		if other != actor:
			other.position = Vector3(80, 0.02, other.actor_id * 3)
	await physics_frame
	assert(game.throw_grenade(actor))
	var grenade = game.grenades.values()[0]
	actor.reload_left = 1.5
	game.sound.volume = 0.3
	var voice = game.sound.effect("explosion", actor.position, false)
	await create_timer(0.05).timeout
	game.grenade_exploded(game.match_id, 7777, Vector3(0, 0.5, 15))
	var blast = game.get_child(game.get_child_count() - 1)
	game.shot_fx(1, actor.eye_position(), actor.eye_position() + Vector3.FORWARD * 4, 0)
	var tracer = game.get_child(game.get_child_count() - 1)
	game.action_latch = {"throw": true}
	game.ui.hit_until = Time.get_ticks_msec() + 300
	game.ui.damage_until = Time.get_ticks_msec() + 600
	game.ui.set_pause(true)
	assert(paused and game.ui.pause_panel.visible and game.action_latch.is_empty())
	assert("paused" in game.ui.pause_description.text)
	var elapsed: float = game.elapsed
	var fuse: float = grenade.fuse
	var grenade_position: Vector3 = grenade.position
	var reload_time: float = actor.reload_left
	var voice_time: float = voice.get_playback_position()
	var animation_time: float = actor.character_animation.player.current_animation_position
	var positions := {}
	for id in game.actors:
		positions[id] = game.actors[id].position
	await create_timer(2.0).timeout
	assert(is_instance_valid(blast) and is_instance_valid(tracer), "Effect lifetime timers pause")
	assert(game.elapsed == elapsed and grenade.fuse == fuse and actor.reload_left == reload_time)
	assert(grenade.position.is_equal_approx(grenade_position), "Rigid body simulation freezes")
	for id in positions:
		assert(game.actors[id].position == positions[id], "All players and bots freeze")
	assert(actor.character_animation.player.current_animation_position == animation_time)
	assert(absf(voice.get_playback_position() - voice_time) < 0.04, "Audio playback pauses too")
	if "--capture-pause" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/solo-pause.png")
	# Input still reaches the game through its always-processing controller.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	assert(not paused and not game.ui.pause_panel.visible, "Escape resumes while tree is paused")
	assert(game.ui.hit_until > Time.get_ticks_msec() + 200 and game.ui.damage_until > Time.get_ticks_msec() + 500, "Feedback retains remaining display duration")
	key.pressed = false
	Input.parse_input_event(key)
	await create_timer(0.12).timeout
	assert(not is_instance_valid(tracer), "Effect timers resume")
	assert(game.elapsed > elapsed and grenade.fuse < fuse and actor.reload_left < reload_time)
	assert(grenade.position.distance_to(grenade_position) > 0.01)
	assert(voice.get_playback_position() > voice_time, "Audio resumes from its paused position")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(paused, "Offline focus loss pauses without automatic resume")
	game.leave()
	assert(not paused and game.ui.menu.visible)
	game.start_solo()
	assert(not paused and not game.ui.pause_panel.visible)
	# Exercise the authoritative online simulation without opening sockets.
	game.online = true
	game.dedicated = true
	game.ui.set_pause(true)
	elapsed = game.elapsed
	assert(not paused and "vulnerable" in game.ui.pause_description.text)
	await create_timer(0.12).timeout
	assert(game.elapsed > elapsed, "Online operation continues through its menu")
	game.dedicated = false
	game.online = false
	game.leave()
	print("PAUSE_RULES_PASS world=ok bots=ok physics=ok fuse=ok reload=ok animation=ok audio=ok effects=ok escape=ok focus=ok resume=ok leave=ok online=continues")
	game.start_solo()
	game.ui.set_pause(true)
	assert(paused)
	game.request_quit()
