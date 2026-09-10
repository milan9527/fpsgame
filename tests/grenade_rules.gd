extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func fixture(game, id: int, origin: Vector3, owner_id: int):
	var grenade = load("res://scripts/grenade.gd").new()
	grenade.grenade_id = id
	grenade.owner_id = owner_id
	grenade.position = origin
	game.add_child(grenade)
	grenade.freeze = true
	game.grenades[id] = grenade
	return grenade

func run() -> void:
	assert(ResourceLoader.exists("res://assets/grenade.glb"), "Blender grenade asset must be packaged")
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null # This fixture must not modify the player's local results.
	await process_frame
	game.start_solo()
	game.running = false
	game.elapsed = 20
	game.sound.volume = 0
	for actor in game.actors.values():
		actor.position = Vector3(100, 1, 100 + actor.actor_id)
	var player = game.actors[1]
	player.position = Vector3(0, 0.02, 10)
	player.yaw = 0
	player.pitch = 0
	var wall = game.world.block(Vector3(0, 2, 6), Vector3(4, 4, 0.25), "465a61")
	await sync_physics()
	assert(game.throw_grenade(player) and player.grenades == 1, "Throw consumes one inventory item")
	assert(not game.throw_grenade(player) and player.grenades == 1, "Cooldown rejects duplicate throws")
	var grenade = game.grenades.values()[0]
	var bounced := false
	for i in range(60):
		await physics_frame
		if grenade.linear_velocity.z > 0.5:
			bounced = true
			break
	assert(bounced and grenade.position.z > 6, "Real rigid-body collision bounces off the wall")
	game.clear_grenades()
	wall.queue_free()
	await sync_physics()
	var close_wall = game.world.block(Vector3(0, 2, 9.65), Vector3(4, 4, 0.1), "465a61")
	await sync_physics()
	player.throw_left = 0
	assert(game.throw_grenade(player))
	grenade = game.grenades.values()[0]
	assert(grenade.position.z > 9.8, "Sphere sweep keeps grenade in front of close cover")
	game.clear_grenades()
	player.grenades = 1
	player.throw_left = 0
	player.position.z = 9.65
	assert(not game.throw_grenade(player) and player.grenades == 1, "Blocked origin rejects throw without consuming stock")
	close_wall.queue_free()
	player.position = Vector3(40, 1, 40)
	await sync_physics()
	var exposed = game.actors[-1]
	var covered = game.actors[-2]
	var distant = game.actors[-3]
	exposed.position = Vector3(0, 0.02, 0)
	covered.position = Vector3(0, 0.02, -6)
	distant.position = Vector3(0, 0.02, 20)
	exposed.armor = 0
	covered.armor = 0
	wall = game.world.block(Vector3(0, 2, -4.5), Vector3(5, 4, 0.3), "465a61")
	grenade = fixture(game, 100, Vector3(0, 0.2, -3), 1)
	grenade.fuse = 0.2
	await sync_physics()
	game.advance_grenades(0.1)
	assert(game.grenades.has(100) and exposed.health == 100, "Fuse does not explode early")
	game.advance_grenades(0.11)
	assert(not game.grenades.has(100) and not exposed.alive, "Fuse explodes once with lethal close-range damage")
	assert(covered.health == 100 and distant.health == 100, "Solid cover and blast radius protect actors")
	var kills: int = player.kills
	game.detonate_grenade(100)
	assert(player.kills == kills, "Repeat detonation cannot duplicate kills")
	wall.queue_free()
	var partial = game.actors[-4]
	partial.position = Vector3(4, 0.02, 0)
	wall = game.world.block(Vector3(2, 0.325, 0), Vector3(0.2, 0.65, 2), "465a61")
	await sync_physics()
	var exposure: float = game.explosion_exposure(Vector3(0, 0.16, 0), partial)
	assert(exposure > 0 and exposure < 1, "Partial cover reduces exposure")
	wall.queue_free()
	await sync_physics()
	# Preserve kill attribution when a thrower disconnects before detonation.
	partial.position = Vector3(0, 0.02, 0)
	partial.armor = 0
	fixture(game, 101, Vector3(0, 0.2, -2), 1)
	var prior: int = game.participants[1].kills
	game.actors.erase(1)
	game.detonate_grenade(101)
	assert(game.participants[1].kills == prior + 1, "Disconnected thrower's result retains explosion kill")
	game.actors[1] = player
	# An old unreliable position packet must not resurrect a reliably exploded grenade.
	game.online = true
	game.network_round_id = "grenade-test"
	game.grenade_exploded("grenade-test", 777, Vector3.ZERO)
	var stale := {"round": "grenade-test", "states": [{"id": 777, "p": Vector3.ZERO, "f": 1, "owner": 1, "kind": 0}], "ids": [777]}
	game.grenade_snapshot(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE))
	assert(not game.grenades.has(777), "Exploded projectile cannot reappear from stale snapshot")
	stale.round = "old-round"
	stale.states[0].id = 778
	stale.ids = [778]
	game.grenade_snapshot(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE))
	assert(not game.grenades.has(778), "Old-round grenade snapshot rejected")
	game.online = false
	fixture(game, 102, Vector3.ZERO, 1)
	game.finish_round()
	assert(game.grenades.is_empty(), "Finishing a round cancels remaining grenades")
	await create_timer(0.6).timeout
	print("GRENADE_RULES_PASS inventory=ok bounce=ok wall_sweep=ok fuse=ok cover=ok radius=ok attribution=ok stale_packets=ok cleanup=ok")
	quit()
