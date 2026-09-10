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
	var player = game.actors[1]
	var ally = game.actors[-1]
	var enemy = game.actors[-2]
	player.armor = 0
	game.damage(player, 150, enemy.actor_id)
	assert(player.alive and player.downed and player.health == 0 and player.down_health == 100)
	assert(player.rank == 0 and enemy.kills == 0 and player.total_ammunition() > 0)
	assert(game.ui.death_recap.is_empty(), "A knock is not a death")
	var ammo: int = player.ammo
	player.fire_left = 0
	game.shoot(player)
	player.heal()
	player.reload_weapon()
	assert(player.ammo == ammo and player.heal_left == 0 and player.reload_left == 0)
	assert(not game.throw_grenade(player) and not game.pickup(player))
	var state: Dictionary = player.pack(true)
	assert(state.downed and state.bleed == 30 and not player.pack().has("downed"))
	var replica = game.Actor.new()
	root.add_child(replica)
	replica.unpack(state, false)
	assert(replica.downed and replica.alive and replica.down_health == 100)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 2, 2)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = (player.position + ally.position) / 2 + Vector3.UP * 0.6
	root.add_child(blocker)
	await physics_frame
	assert(not game.rescue.interact(game, ally), "Cannot rescue through walls")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	assert(not game.rescue.interact(game, enemy), "Enemies cannot rescue")
	assert(game.rescue.interact(game, ally))
	game.rescue.update(game, 2)
	assert(ally.revive_left == 3 and player.downed)
	game.damage(ally, 1, enemy.actor_id)
	assert(ally.revive_target == 0, "Damage to rescuer interrupts")
	assert(game.rescue.interact(game, ally))
	game.damage(player, 10, enemy.actor_id)
	assert(player.down_health == 90 and ally.revive_target == 0, "Damage to patient interrupts")
	assert(game.rescue.interact(game, ally))
	ally.move_input = Vector2.ONE
	game.rescue.update(game, 0.1)
	assert(ally.revive_target == 0)
	ally.move_input = Vector2.ZERO
	assert(game.rescue.interact(game, ally))
	var original: Vector3 = ally.position
	ally.position += Vector3(10, 0, 0)
	game.rescue.update(game, 0.1)
	assert(ally.revive_target == 0, "Distance is continuously checked")
	ally.position = original
	assert(game.rescue.interact(game, ally))
	assert(game.rescue.interact(game, ally) and ally.revive_target == 0, "Second interaction cancels")
	var cmd: Dictionary = game.local_command(ally)
	cmd.seq = 100
	cmd.loot = true
	assert(game.receive_actions(ally, game.match_id, cmd))
	assert(ally.revive_target == 1)
	assert(not game.receive_actions(ally, game.match_id, cmd), "Replay cannot cancel rescue")
	game.rescue.update(game, 4.9)
	assert(player.downed)
	game.rescue.update(game, 0.1)
	assert(not player.downed and player.alive and player.health == 30 and ally.revive_target == 0)
	replica.unpack(player.pack(true), false)
	assert(not replica.downed and replica.alive and replica.health == 30)
	replica.queue_free()
	# Bot uses the same five-second rescue rather than assigning health directly.
	game.damage(player, 100, enemy.actor_id)
	assert(player.downed)
	game.bot_input(ally, 0.1)
	assert(ally.revive_target == 1 and player.downed)
	game.rescue.update(game, 5)
	assert(not player.downed and player.health == 30)
	# Bleed-out retains the original attacker and awards exactly one elimination.
	game.damage(player, 100, enemy.actor_id)
	game.rescue.update(game, 30)
	assert(not player.alive and enemy.kills == 1 and player.rank == 0)
	game.damage(player, 100, enemy.actor_id)
	assert(enemy.kills == 1)
	# The final standing member cannot knock; their downed teammate is wiped.
	game.start_solo("duo")
	game.elapsed = 20
	player = game.actors[1]
	ally = game.actors[-1]
	enemy = game.actors[-2]
	game.damage(player, 10000, enemy.actor_id)
	assert(player.downed)
	game.damage(ally, 10000, enemy.actor_id)
	assert(not ally.alive)
	game.rescue.update(game, 0.01)
	assert(not player.alive and player.rank == ally.rank and player.rank == 8)
	assert(enemy.kills == 2)
	game.start_solo("duo")
	game.elapsed = 20
	player = game.actors[1]
	player.health = 10
	player.armor = 100
	game.damage(player, 30, -2)
	assert(player.downed and player.armor == 82)
	game.damage(player, 100, -2)
	assert(not player.alive and game.ui.death_recap.health_damage == 100)
	assert(game.ui.death_recap.armor_damage == 0, "Downed damage cannot double-charge armor")
	var recovered_armor := 0.0
	for item in game.loot.values():
		if item.get("drop_slot", -1) == 2 and item.p == player.position:
			recovered_armor += item.amount
	assert(recovered_armor == 82, "Finisher preserves the remaining armor in the death drop")
	# Solo fatal damage remains immediate and old checkpoint fields stay valid.
	game.start_solo()
	game.elapsed = 20
	player = game.actors[1]
	game.damage(player, 10000, -1)
	assert(not player.alive and not player.downed)
	print("RESCUE_RULES_PASS knock=ok restrictions=ok interrupt=ok reliable_replay=ok revive=ok bots=ok bleed=ok wipe=ok solo=ok")
	game.request_quit()
