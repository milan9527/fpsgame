extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.running = false
	game.elapsed = 10
	game.sound.volume = 0
	var actor = game.actors[1]
	actor.position = Vector3(0, 0.02, 20)
	actor.yaw = 0
	actor.pitch = 0
	await physics_frame
	var cmd: Dictionary = game.local_command(actor)
	cmd.seq = 10
	cmd.throw = true
	cmd.yaw = 0.5
	cmd.pitch = 0.2
	var movement: Dictionary = game.without_actions(cmd)
	assert(not game.has_actions(movement) and cmd.throw)
	game.apply_command(actor, movement)
	assert(actor.grenades == 2, "Unreliable movement never executes a one-shot")
	actor.yaw = 0
	actor.pitch = 0
	assert(not game.receive_actions(actor, "old-round", cmd))
	assert(actor.last_action_sequence == -1 and actor.grenades == 2)
	assert(game.receive_actions(actor, game.match_id, cmd))
	assert(actor.grenades == 1 and game.grenades.size() == 1)
	assert(actor.yaw == 0 and actor.pitch == 0, "Event aim cannot overwrite newer held view")
	var grenade = game.grenades.values()[0]
	var direction := Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.2) * Vector3.FORWARD
	assert(grenade.linear_velocity.is_equal_approx(direction * 17 + Vector3.UP * 3), "Throw uses event aim")
	actor.throw_left = 0
	assert(not game.receive_actions(actor, game.match_id, cmd))
	assert(actor.grenades == 1, "Duplicate cannot consume a second grenade even after cooldown")
	cmd.seq = 9
	assert(not game.receive_actions(actor, game.match_id, cmd), "Out-of-order replay rejected")
	cmd.seq = 11.5
	assert(not game.receive_actions(actor, game.match_id, cmd), "Fractional sequence rejected")
	cmd.seq = 11
	cmd.throw = false
	cmd.jump = true
	assert(game.receive_actions(actor, game.match_id, cmd) and actor.jump_requested)
	actor.jump_requested = false
	assert(not game.receive_actions(actor, game.match_id, cmd) and not actor.jump_requested)
	cmd.seq = 12
	cmd.jump = false
	cmd.reload = true
	actor.ammo = 5
	assert(game.receive_actions(actor, game.match_id, cmd) and actor.reload_left > 0)
	actor.reload_left = 0
	cmd.seq = 13
	cmd.reload = false
	cmd.heal = true
	actor.health = 50
	assert(game.receive_actions(actor, game.match_id, cmd) and actor.heal_left > 0)
	actor.heal_left = 0
	cmd.seq = 14
	cmd.heal = false
	cmd.weapon = 1
	assert(game.receive_actions(actor, game.match_id, cmd) and actor.weapon == 1)
	cmd.weapon = -1
	cmd.loot = true
	cmd.seq = 15
	actor.last_sequence = 200
	assert(not game.receive_actions(actor, game.match_id, cmd), "Stale backlog is dropped")
	cmd.seq = 201
	actor.action_tokens = 0
	assert(not game.receive_actions(actor, game.match_id, cmd))
	actor.action_tokens = 10
	assert(not game.receive_actions(actor, game.match_id, cmd), "Rate-limited event cannot be replayed later")
	cmd.seq = 202
	actor.alive = false
	assert(not game.receive_actions(actor, game.match_id, cmd))
	actor.alive = true
	game.phase = "finished"
	assert(not game.receive_actions(actor, game.match_id, cmd))
	print("RELIABLE_ACTIONS_RULES_PASS movement_separation=ok throw_once=ok event_aim=ok jump=ok reload=ok heal=ok switch=ok replay=ok round=ok stale=ok rate=ok dead=ok")
	game.queue_free()
	await process_frame
	quit()
