extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.running = false
	game.sound.volume = 0
	game.elapsed = 20
	for actor in game.actors.values():
		actor.position = Vector3(90, 1, 90 + actor.actor_id)
	var shooter = game.actors[1]
	var target = game.actors[-1]
	shooter.position = Vector3(0, 0.02, 5)
	target.position = Vector3(0, 0.02, -5)
	shooter.yaw = 0
	shooter.pitch = 0
	var car = load("res://scripts/vehicle.gd").new()
	game.add_child(car)
	await sync_physics()
	var origin := Vector3(0, 1.1, 5)
	var hit: Dictionary = game.trace_shot(shooter, origin, Vector3.FORWARD, 0)
	assert(hit.collider == car)
	game.hit_history.record(19.8, game.actors)
	game.hit_history.record(20, game.actors)
	hit = game.trace_shot(shooter, origin, Vector3.FORWARD, 0.1)
	assert(hit.collider == car, "Rewound characters must not be hit through current vehicle cover")
	var health: float = target.health
	var ammo: int = shooter.ammo
	game.shoot(shooter)
	assert(target.health == health and shooter.ammo == ammo - 1, "Vehicle hits must not invoke Actor-only headshot/damage methods")
	assert(not game.visible_target(shooter, target))
	assert(game.explosion_exposure(Vector3(0, 0.6, 4), target) == 0)
	target.position.x = 6
	await sync_physics()
	assert(game.explosion_exposure(Vector3(0, 0.6, 4), target) > 0)
	shooter.move_input = Vector2(0, -1)
	for _step in range(90):
		shooter.simulate(1.0 / 60)
	assert(shooter.position.z > 2.15 and shooter.position.z < 2.4, "Infantry must stop at the vehicle hull")
	shooter.move_input = Vector2.ZERO
	shooter.position = Vector3(0, 0.02, 1.95)
	await sync_physics()
	assert(shooter.weapon_obstructed(false))
	shooter.position = Vector3(1.3, 0.02, 0)
	target.position = Vector3(-1.3, 0.02, 0)
	shooter.team_id = 1
	target.team_id = 1
	target.downed = true
	await sync_physics()
	assert(not game.rescue.accessible(game, shooter, target))
	assert(not game.supply_accessible(shooter, {"p": target.position}))
	var grenade = load("res://scripts/grenade.gd").new()
	grenade.position = Vector3(0, 0.8, 4)
	game.add_child(grenade)
	assert(grenade.collision_layer == 8 and grenade.collision_mask == 5)
	grenade.linear_velocity = Vector3(0, 0, -10)
	var bounced := false
	for _step in range(40):
		await physics_frame
		if grenade.linear_velocity.z > 0.5:
			bounced = true
			break
	assert(bounced and grenade.position.z > 1.8)
	grenade.freeze = true
	grenade.position = Vector3(0, 1.1, 0)
	await sync_physics()
	assert(car.can_rotate(0), "Grenades must not count as vehicle rotation obstacles")
	car.queue_free()
	target.downed = false
	target.position = Vector3(0, 0.02, -5)
	shooter.position = Vector3(0, 0.02, 5)
	await sync_physics()
	hit = game.trace_shot(shooter, origin, Vector3.FORWARD, 0)
	assert(hit.collider == target, "Grenades are not bullet cover")
	game.queue_free()
	await process_frame
	print("VEHICLE_COVER_PASS bullet=ok rewind=ok typed_hit=ok infantry=ok muzzle=ok blast=ok rescue=ok loot=ok grenade_bounce=ok grenade_layer=ok")
	quit()
