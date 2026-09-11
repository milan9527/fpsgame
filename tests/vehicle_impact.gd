extends SceneTree
var game
var driver

func _initialize() -> void:
	call_deferred("run")

func sync_physics() -> void:
	await physics_frame
	await physics_frame

func fresh_car():
	game.vehicle_fleet.clear()
	driver.position = Vector3(-1.65, 0.04, 0.1)
	driver.health = 100
	driver.armor = 0
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await sync_physics()
	for _step in range(5):
		game.vehicle_fleet.step(1.0 / 60, true)
	assert(car.seats.enter(driver, 0))
	assert(car.can_rotate(0.2), "Own occupants must not prevent steering")
	return car

func tick(car, pedal := 1.0) -> void:
	if car.driver_id != 0:
		assert(car.command(car.driver_id, car.input_sequence + 1, pedal, 0, false, car.seats.epoch))
	game.vehicle_fleet.step(1.0 / 60, true)
	await physics_frame

func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.running = false
	game.elapsed = 20
	game.sound.volume = 0
	for actor in game.actors.values():
		actor.position = Vector3(90, 1, 90 + actor.actor_id)
	driver = game.actors[1]
	var pedestrian = game.spawn_actor(201, "Impact target", false, Vector3(0, 0.02, -15))
	pedestrian.armor = 0
	var car = await fresh_car()
	for _step in range(180):
		await tick(car)
		if not pedestrian.alive:
			break
	assert(not pedestrian.alive and driver.kills == 1, "High-speed impact must use normal kill attribution")
	assert(car.health < car.MAX_HEALTH and car.health > 500)
	assert(car.global_position.z > -14, "Sweep must hit the pedestrian before passing through")
	# A low-speed contact blocks motion without doing collision damage.
	pedestrian.position = Vector3(90, 0, 70)
	var slow_target = game.spawn_actor(202, "Slow target", false, Vector3(0, 0.02, -3))
	slow_target.armor = 0
	car = await fresh_car()
	for _step in range(90):
		await tick(car, 0.1)
	assert(slow_target.health == 100 and car.health == car.MAX_HEALTH)
	assert(car.position.z > -1 and car.position.z < 0)
	slow_target.position = Vector3(90, 0, 75)
	car = await fresh_car()
	var runner = game.spawn_actor(204, "Runner", false, Vector3(0, 0.02, -5))
	runner.armor = 0
	runner.yaw = PI
	runner.move_input = Vector2(0, -1)
	for _step in range(90):
		runner.simulate(1.0 / 60)
		await tick(car, 0)
	assert(runner.health == 100 and car.health == car.MAX_HEALTH, "Walking into a parked car must not cause run-over damage")
	runner.move_input = Vector2.ZERO
	runner.position = Vector3(90, 0, 65)
	# Severe wall impact injures the cabin and hull once; holding throttle
	# against the wall must not grind away health every frame.
	var wall = game.world.block(Vector3(0, 2, -15), Vector3(8, 4, 0.2), "465a61")
	car = await fresh_car()
	for _step in range(180):
		await tick(car)
		if car.health < car.MAX_HEALTH:
			break
	assert(car.health < car.MAX_HEALTH and driver.health < 100 and driver.health > 0)
	var hull: float = car.health
	var health: float = driver.health
	for _step in range(90):
		await tick(car)
	assert(car.health == hull and driver.health == health)
	assert(car.position.z > -13.2)
	wall.queue_free()
	await sync_physics()
	# Two cars share a contact cooldown even when both report the collision.
	car = await fresh_car()
	var parked = game.vehicle_fleet.spawn(game, Vector3(0, 0, -16))
	await sync_physics()
	for _step in range(180):
		await tick(car)
		if parked.health < parked.MAX_HEALTH:
			break
	assert(parked.health < parked.MAX_HEALTH and car.health < car.MAX_HEALTH)
	var car_hull: float = car.health
	var parked_hull: float = parked.health
	game.vehicle_fleet.on_impact(car, 20, 0, game, parked)
	assert(car.health == car_hull and parked.health == parked_hull, "Reverse pair report must not apply the same crash twice")
	for _step in range(30):
		await tick(car)
	assert(car.health == car_hull and parked.health == parked_hull)
	assert(car.position.z > -12.5)
	# Opposing moving cars exercise relative velocity and both simulation orders.
	car = await fresh_car()
	var opposing = game.vehicle_fleet.spawn(game, Vector3(0, 0, -26), PI)
	await sync_physics()
	for _step in range(5):
		game.vehicle_fleet.step(1.0 / 60, true)
	var other_driver = game.spawn_actor(203, "Opposing driver", false, opposing.to_global(opposing.seats.DOORS[0]) - Vector3.UP * 0.86)
	other_driver.armor = 0
	assert(opposing.seats.enter(other_driver, 0))
	for _step in range(180):
		if opposing.driver_id != 0:
			assert(opposing.command(other_driver.actor_id, opposing.input_sequence + 1, 1, 0, false, opposing.seats.epoch))
		await tick(car)
		if opposing.health < opposing.MAX_HEALTH:
			break
	assert(car.health < car.MAX_HEALTH and opposing.health < opposing.MAX_HEALTH)
	assert(is_equal_approx(car.health, opposing.health) and car.health >= 200, "Head-on collision must charge one symmetric hull impact, capped at 400")
	print("HEAD_ON_HULL ", car.health, " ", opposing.health)
	assert(is_equal_approx(car.health, 200), "Two closing 13 m/s vehicles must use their combined normal speed")
	assert(driver.health < 100 and other_driver.health < 100)
	game.clear_actors()
	assert(game.vehicle_fleet.pair_cooldowns.is_empty())
	game.queue_free()
	await process_frame
	print("VEHICLE_IMPACT_PASS occupants_excluded=ok pedestrian_sweep=ok attribution=ok low_speed=ok hull_cabin=ok no_grinding_damage=ok vehicle_pair=ok cleanup=ok")
	quit()
