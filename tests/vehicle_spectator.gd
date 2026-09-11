extends SceneTree
var game

func _initialize() -> void:
	call_deferred("run")

func render_view() -> void:
	game._process(1.0 / 60)
	await physics_frame
	await physics_frame
	await process_frame

func run() -> void:
	game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("duo")
	game.elapsed = 10
	for actor in game.actors.values():
		actor.is_bot = false
		actor.position = Vector3(90, 0.1, 90 + actor.actor_id)
	var local = game.actors[1]
	var ally = game.actors[-1]
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	ally.position = Vector3(-1.65, 0.04, 0.1)
	await physics_frame
	await physics_frame
	for _i in range(5):
		car.simulate(1.0 / 60)
	assert(car.seats.enter(ally, 0))
	game.damage(local, 10000, -2, true)
	game.damage(local, 10000, -2, true)
	await render_view()
	var spectator = game.spectator
	assert(spectator.active and spectator.target_id == -1 and spectator.camera.current)
	assert(spectator.position.is_equal_approx(car.position + Vector3.UP * 1.4))
	assert(spectator.arm.get_hit_length() > 4.3, "The followed vehicle must not collapse its own spectator camera")
	var parked = game.vehicle_fleet.spawn(game, Vector3(0, 0, 3.6))
	await render_view()
	await render_view()
	assert(spectator.arm.get_hit_length() < 2.5, "Another vehicle must block the spectator camera")
	game.vehicle_fleet.vehicles.erase(parked.vehicle_id)
	parked.queue_free()
	await render_view()
	await render_view()
	assert(spectator.arm.get_hit_length() > 4.3)
	for sequence in range(90):
		await physics_frame
		assert(car.command(ally.actor_id, sequence, 1, 0, false, car.seats.epoch))
		car.simulate(1.0 / 60)
		await render_view()
		assert(spectator.position.is_equal_approx(car.position + Vector3.UP * 1.4))
	print("VEHICLE_SPECTATOR_MOTION speed=%.3f position=%s grounded=%s fuel=%.3f" % [car.speed, car.position, car.grounded, car.fuel])
	assert(car.speed > 10 and car.position.z < -5)
	for sequence in range(90, 180):
		await physics_frame
		assert(car.command(ally.actor_id, sequence, 0, 0, true, car.seats.epoch))
		car.simulate(1.0 / 60)
	assert(car.seats.exit(ally))
	# The formerly excluded car must obstruct the camera after the ally exits.
	ally.position = car.position + Vector3(0, 0, -4)
	spectator.orbit_pitch = 0
	await render_view()
	await render_view()
	assert(spectator.position.is_equal_approx(ally.position + Vector3.UP * ally.eye_height()))
	assert(spectator.arm.get_hit_length() < 2.5, "Seat exit must clear the vehicle collision exception")
	spectator.select(-2, game.actors)
	assert(spectator.target_id == -1, "Vehicle spectating must retain team restrictions")
	game.damage(ally, 10000, -2, true)
	await render_view()
	assert(spectator.target_id == 0 and "TEAM ELIMINATED" in game.ui.spectator_label.text)
	game.start_solo("duo")
	await render_view()
	assert(not spectator.active and game.actors[1].camera.current)
	print("VEHICLE_SPECTATOR_PASS seated_pivot=ok own_hull_excluded=ok other_car_cover=ok motion=ok exit=ok team_filter=ok reset=ok")
	game.request_quit()
