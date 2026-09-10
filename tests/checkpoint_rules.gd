extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var location := "user://qa-checkpoint-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(location)
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.sound.volume = 0
	game.local_profile = load("res://scripts/local_profile.gd").new(location + "/results")
	game.checkpoint.path = location + "/checkpoint.dat"
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.elapsed = 60.0
	var player = game.actors[1]
	player.position = Vector3(0, 1, 20)
	player.health = 70
	player.armor = 34
	player.weapon = 2
	player.magazines = PackedInt32Array([17, 3, 1])
	player.reserve = 90
	player.medkits = 1
	player.smokes = 1
	player.reload_left = 0.6
	player.yaw = 0.4
	player.pitch = 0.2
	player.set_stance(true)
	player.lean = 0.5
	game.loot[0].amount = 9.0
	game.damage(game.actors[-1], 10000, 1, true)
	game.smoke_clouds[40] = {"p": Vector3(0, 2, 10), "age": 5.0}
	var grenade = game.Grenade.new()
	grenade.grenade_id = 41
	grenade.owner_id = 1
	grenade.position = Vector3(0, 2, 15)
	grenade.fuse = 1.7
	game.add_child(grenade)
	grenade.linear_velocity = Vector3(2, 1, -4)
	grenade.angular_velocity = Vector3(1, 2, 3)
	game.grenades[41] = grenade
	game.next_grenade_id = 42
	game.ui.tactical_map.waypoint = Vector2(30, 40)
	var id: String = game.match_id
	var expected: Dictionary = game.snapshot_solo()
	assert(game.checkpoint.validate(expected, game.build_info.content_revision))
	assert(game.suspend_solo())
	assert(not game.running and game.phase == "standby")
	assert(game.local_profile.read_record(id).state == "missing", "Suspend is not an abandoned result")
	assert(game.resume_solo())
	assert(paused and game.running and game.match_id == id and game.elapsed == 60)
	player = game.actors[1]
	assert(player.position == Vector3(0, 1, 20) and player.health == 70 and player.armor == 34)
	assert(player.weapon == 2 and player.magazines == PackedInt32Array([17, 3, 1]) and player.reserve == 90)
	assert(player.reload_left == 0.6 and player.smokes == 1 and player.crouched and player.lean == 0.5)
	assert(not game.actors[-1].alive and game.actors[-1].rank == 16 and player.kills == 1)
	assert(game.grenades[41].fuse == 1.7 and game.grenades[41].linear_velocity == Vector3(2, 1, -4))
	assert(game.smoke_clouds[40].age == 5 and game.loot[0].amount == 9)
	assert(game.zone_plan.centers == expected.centers and game.rng.state == expected.rng_state)
	assert(game.ui.tactical_map.waypoint == Vector2(30, 40))
	if "--capture-checkpoint" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../artifacts/checkpoint-pause.png")
	for bot in game.actors.values():
		if bot.is_bot:
			bot.bot_think = 5
			bot.target_id = 0
	game.ui.set_pause(false)
	for tick in range(60):
		await physics_frame
		game._physics_process(1.0 / 60)
	game.ui.set_pause(true)
	assert(player.ammo == 5 and player.reserve == 86, "Restored reload finishes using saved stock")
	assert(game.grenades[41].fuse < 0.71 and game.smoke_clouds[40].age > 5.99, "Restored fuses and smoke resume advancing")
	game.checkpoint.path = location + "/missing/blocked.dat"
	assert(not game.suspend_solo() and game.running and paused and game.actors.size() == 16)
	game.checkpoint.path = location + "/checkpoint.dat"
	game.elapsed = 70
	assert(game.suspend_solo())
	var file := FileAccess.open(game.checkpoint.path, FileAccess.WRITE)
	file.store_buffer(var_to_bytes({"payload": PackedByteArray([1, 2]), "sha": "wrong"}))
	file.close()
	var restored: Dictionary = game.checkpoint.load_state(game.build_info.content_revision)
	assert(restored.elapsed == 60 and "Recovered" in game.checkpoint.last_error)
	assert(game.resume_solo() and game.elapsed == 60)
	var malformed: Dictionary = restored.duplicate(true)
	malformed.actors[0].mags = PackedInt32Array([999, 0, 0])
	assert(not game.checkpoint.validate(malformed, game.build_info.content_revision))
	assert(not game.checkpoint.validate(restored, "different-map"))
	for actor in game.actors.values():
		if actor.actor_id != 1 and actor.alive:
			game.damage(actor, 10000, 1, true)
	game.finish_round()
	assert(game.local_profile.read_record(id).record.status == "completed")
	game.leave()
	assert(not game.resume_solo() and not game.running, "Finalized result cannot be replayed from an old checkpoint")
	assert(game.local_profile.summary().completed == 1)
	print("CHECKPOINT_RULES_PASS state_roundtrip=ok inventory_timers=ok corpses=ok projectiles=ok clouds=ok zones_rng=ok no_abandon=ok write_failure=ok backup=ok schema=ok finalized_guard=ok")
	game.queue_free()
	await process_frame
	quit()
