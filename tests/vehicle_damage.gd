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
	for other in game.actors.values():
		other.position = Vector3(90, 1, 90 + other.actor_id)
	var actor = game.actors[1]
	var shooter = game.actors[-1]
	shooter.is_bot = false
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await sync_physics()
	for _step in range(5):
		car.simulate(1.0 / 60)
	actor.position = Vector3(-1.65, 0.04, 0.1)
	assert(car.seats.enter(actor, 0))
	var fuel: float = car.fuel
	for index in range(60):
		assert(car.command(actor.actor_id, index, 0, 0, true, car.seats.epoch))
		car.simulate(1.0 / 60)
	assert(absf(car.fuel - (fuel - 0.1)) < 0.0001)
	fuel = car.fuel
	game.vehicle_fleet.step(1.0 / 60, false)
	assert(car.fuel == fuel, "Finished/lobby states do not consume fuel")
	car.fuel = 0.001
	car.command(actor.actor_id, 60, 1, 0, false, car.seats.epoch)
	car.simulate(1.0 / 60)
	assert(car.fuel == 0 and absf(car.speed) < 0.01)
	car.command(actor.actor_id, 61, 1, 0, false, car.seats.epoch)
	car.simulate(1.0 / 60)
	assert(car.fuel == 0 and absf(car.speed) < 0.01)
	assert(car.take_damage(NAN) == 0 and car.take_damage(-1) == 0 and car.health == car.MAX_HEALTH)
	shooter.position = Vector3(0, 0.02, 6)
	shooter.yaw = 0
	shooter.pitch = 0
	await sync_physics()
	game.shoot(shooter)
	assert(car.health < car.MAX_HEALTH and car.health > car.MAX_HEALTH - 100)
	var health: float = car.health
	var wall = game.world.block(Vector3(0, 1.5, 3), Vector3(8, 3, 0.2), "465a61")
	await sync_physics()
	game.vehicle_fleet.blast(game, Vector3(0, 0.6, 5), shooter.actor_id, 9, 360)
	assert(car.health == health, "Solid walls shield vehicle explosion damage")
	wall.queue_free()
	await sync_physics()
	game.vehicle_fleet.blast(game, Vector3(0, 0.6, 5), shooter.actor_id, 9, 360)
	assert(car.health < health and not car.destroyed)
	var passenger = game.actors[-2]
	passenger.position = Vector3(1.65, 0.04, 0.1)
	assert(car.seats.enter(passenger, 1))
	var armor: float = actor.armor
	var before: float = actor.health
	var passenger_health: float = passenger.health
	health = car.health
	var blockers: Array = []
	for point in car.seats.EXIT_POINTS:
		blockers.append(game.world.block(car.to_global(point) + Vector3.UP, Vector3(0.9, 2, 0.9), "465a61"))
	await sync_physics()
	assert(car.take_damage(10000, shooter.actor_id) == health)
	assert(car.destroyed and car.health == 0 and car.driver_id == 0 and car.collision_layer == 4)
	assert(actor.health == before - 40 and actor.armor == armor and passenger.health == passenger_health - 40)
	assert(car.take_damage(10000, shooter.actor_id) == 0 and actor.health == before - 40, "Wreck injury fires exactly once")
	assert(not car.command(actor.actor_id, 62, 1, 0, false, car.seats.epoch))
	car.simulate(1.0 / 60)
	assert(actor.is_seated() and passenger.is_seated() and car.driver_id == 0, "Blocked wreck exits retain occupants without restoring engine authority")
	for blocker in blockers:
		blocker.queue_free()
	await sync_physics()
	car.simulate(1.0 / 60)
	assert(not actor.is_seated() and not passenger.is_seated())
	actor.position = Vector3(-1.65, 0.04, 0.1)
	assert(not car.seats.enter(actor, 0))
	assert(game.vehicle_fleet.candidates(actor).is_empty())
	assert(car.visual.find_children("*", "MeshInstance3D", true, false)[0].material_override != null)
	# Real grenade detonation must call the fleet damage path.
	var second = game.vehicle_fleet.spawn(game, Vector3(10, 0, 0))
	await sync_physics()
	var grenade = game.Grenade.new()
	grenade.grenade_id = 900
	grenade.owner_id = shooter.actor_id
	grenade.position = Vector3(10, 0.6, 2.5)
	game.add_child(grenade)
	grenade.freeze = true
	game.grenades[900] = grenade
	game.detonate_grenade(900)
	assert(second.health < second.MAX_HEALTH)
	if DisplayServer.get_name() != "headless":
		game.ui.hud.hide()
		for other in game.actors.values():
			other.render_frame(0.1, false, false, false)
			other.gun.hide() # External inspection camera must not draw the first-person viewmodel.
		var camera := Camera3D.new()
		game.add_child(camera)
		camera.position = Vector3(5, 3, -6)
		camera.look_at(Vector3(0, 0.9, 0))
		camera.current = true
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://../artifacts/vehicle-wreck.png") == OK)
	game.queue_free()
	await process_frame
	print("VEHICLE_DAMAGE_PASS fuel=ok empty_tank=ok invalid_damage=ok bullets=ok blast_cover=ok grenade=ok wreck=ok cabin_injury_once=ok safe_exit=ok no_reentry=ok")
	quit()
