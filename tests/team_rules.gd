extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo("duo")
	game.set_physics_process(false)
	game.set_process(false)
	game.elapsed = 20
	assert(game.actors.size() == 16 and game.teams.members.size() == 8)
	var player = game.actors[1]
	var ally = game.actors[-1]
	assert(player.team_id == 1 and ally.team_id == 1)
	assert(player.position.distance_to(ally.position) < 3)
	for team in game.teams.members:
		var pair: Array = game.teams.members[team]
		assert(pair.size() == 2)
		var center: Vector3 = (game.actors[pair[0]].position + game.actors[pair[1]].position) / 2
		assert(game.world.accepts_zone_center(Vector2(center.x, center.z)))
	var hp: float = player.health
	var armor: float = player.armor
	game.damage(player, 500, -1, true)
	game.damage(player, 500, -1, true, false, "FRAG", ally.position)
	assert(player.health == hp and player.armor == armor and player.alive)
	game.actors.erase(-1)
	game.damage(player, 500, -1, true, false, "FRAG", ally.position)
	assert(player.health == hp, "Disconnected thrower retains team membership for damage attribution")
	game.actors[-1] = ally
	assert(not game.visible_target(ally, player))
	ally.bot_think = 0
	game.bot_input(ally, 0.02)
	assert(not game.teams.friendly(ally.actor_id, ally.target_id), "Bots cannot choose teammates as enemies")
	game.damage(player, 5, 1, true, false, "FRAG", player.position)
	assert(player.health + player.armor < hp + armor, "Self damage remains active")
	var replica = game.Actor.new()
	root.add_child(replica)
	replica.unpack(ally.pack(true), false)
	assert(replica.team_id == 1)
	replica.unpack(ally.pack(), false)
	assert(replica.team_id == 0 and not ally.pack().has("team"), "Solo checkpoint representation stays compatible")
	replica.queue_free()
	assert(not game.suspend_solo(), "Incomplete duo persistence cannot overwrite the solo save")
	game.damage(player, 10000, -2, true)
	assert(not player.alive and player.rank == 0 and game.teams.living(game.actors).size() == 8)
	game.ui.set_spectator(true, ally.display_name, player.rank)
	assert("TEAM STILL ACTIVE" in game.ui.spectator_label.text)
	for team in range(2, 9):
		var pair: Array = game.teams.members[team]
		game.damage(game.actors[pair[0]], 10000, -1, true)
		assert(game.actors[pair[0]].rank == 0)
		game.damage(game.actors[pair[1]], 10000, -1, true)
		assert(game.actors[pair[0]].rank == game.actors[pair[1]].rank)
	assert(game.teams.living(game.actors) == [1])
	game.finish_round()
	assert(player.rank == 1 and ally.rank == 1 and game.participants[1].rank == 1)
	assert(game.local_outbox.is_empty() and game.result_outbox.is_empty(), "Unreleased duo results must not enter solo statistics")
	game.start_solo("duo")
	game.set_physics_process(false)
	game.elapsed = 20
	for team in range(2, 9):
		for id in game.teams.members[team]:
			game.damage(game.actors[id], 10000, 1, true)
	assert(game.alive_count() == 2 and game.phase == "live")
	game._physics_process(1.0 / 60)
	assert(game.phase == "finished" and game.actors[1].rank == 1 and game.actors[-1].rank == 1, "Two surviving teammates end the match as one winning team")
	game.start_solo("duo")
	game.set_physics_process(false)
	for id in game.teams.members[1]:
		game.actors[id].health = 10
	game.actors[game.teams.members[3][0]].kills = 7
	game.finish_round()
	assert(game.teams.ranks[3] == 1 and game.teams.ranks[2] == 2 and game.teams.ranks[1] == 8)
	game.start_solo()
	game.set_physics_process(false)
	assert(game.match_mode == "solo" and game.teams.members.is_empty())
	assert(game.checkpoint.validate(game.snapshot_solo(), game.build_info.content_revision))
	player = game.actors[1]
	game.damage(player, 5, -1, true)
	assert(player.health + player.armor < 150, "Solo damage rules remain unrestricted")
	print("TEAM_RULES_PASS assignment=ok safe_spawns=ok friendly_fire=blocked self_damage=ok disconnected_owner=ok bots=ok snapshots=ok elimination=ok team_ranks=ok timeout=ok solo_compatibility=ok")
	game.request_quit()
