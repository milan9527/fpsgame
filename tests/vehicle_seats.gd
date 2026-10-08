extends SceneTree
const Vehicle = preload("res://scripts/vehicle.gd")
const Actor = preload("res://scripts/actor.gd")
var car

func _initialize() -> void:
	call_deferred("run")

func sync_space() -> void:
	await physics_frame
	await physics_frame

func actor_at(id: int, at: Vector3):
	var actor := Actor.new()
	actor.actor_id = id
	root.add_child(actor)
	actor.position = at
	return actor

func obstacle(at: Vector3, size := Vector3(0.8, 2, 0.8)) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body

func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.phase = "live"
	car = Vehicle.new()
	root.add_child(car)
	await sync_space()
	for _i in range(4):
		await physics_frame
		car.simulate(1.0 / 60)
	assert(car.grounded)
	var a = actor_at(11, Vector3(-2, 0, 0.1))
	var b = actor_at(12, Vector3(2, 0, 0.1))
	var far = actor_at(13, Vector3(20, 0, 0))
	await sync_space()
	var fleet = load("res://scripts/vehicle_fleet.gd").new()
	assert(fleet.nearest_seat_index(a) == -1)
	fleet.vehicles[1] = car
	assert(fleet.nearest_seat_index(a) == 0)
	assert(fleet.nearest_seat_index(b) == 1)
	assert(fleet.nearest_seat_index(far) == -1)
	# Door reuse must follow each transform immediately, without waiting for
	# another frame or retaining a previous search's coordinates.
	for heading in [-1.0, 0.7, PI]:
		car.rotation.y = heading
		for subject in [a, b, far]:
			for seat in range(2):
				var door: Vector3 = car.to_global(car.seats.DOORS[seat])
				assert(car.seats.can_enter(subject, seat, door) == car.seats.can_enter(subject, seat))
			var choices: Array = fleet.candidates(subject)
			assert(fleet.nearest_seat_index(subject) == (-1 if choices.is_empty() else choices[0].seat))
	car.rotation.y = 0
	assert(not car.seats.enter(far, 0))
	assert(not car.seats.enter(a, 2))
	a.downed = true
	assert(fleet.nearest_seat_index(a) == -1)
	assert(fleet.candidates(a).is_empty())
	assert(not car.seats.enter(a, 0))
	a.downed = false
	a.alive = false
	assert(fleet.nearest_seat_index(a) == -1 and fleet.candidates(a).is_empty())
	a.alive = true
	a.revive_target = b.actor_id
	assert(fleet.nearest_seat_index(a) == -1 and fleet.candidates(a).is_empty())
	a.revive_target = 0
	assert(fleet.nearest_seat_index(a) == 0 and not fleet.candidates(a).is_empty())
	car.speed = 3
	assert(fleet.nearest_seat_index(a) == -1)
	assert(not car.seats.enter(a, 0))
	car.speed = 0
	var wall := obstacle(Vector3(-1.8, 1, 0.1), Vector3(0.1, 2, 1))
	await sync_space()
	assert(not car.seats.enter(a, 0), "Entry must not cross walls")
	assert(fleet.nearest_seat_index(a) == -1, "HUD must respect entry walls")
	wall.queue_free()
	await process_frame
	await sync_space()
	a.health = 50
	a.ammo = 20
	a.reload_left = 1
	a.heal_left = 1
	var ammo: int = a.total_ammunition()
	var meds: int = a.medkits
	assert(car.seats.enter(a, 0))
	assert(fleet.nearest_seat_index(a) == -1, "Seated actors have no entry prompt")
	assert(fleet.nearest_seat_index(b) == 1, "Occupied driver seat must not hide passenger prompt")
	assert(a.is_seated() and a.vehicle_seat == 0 and a.collision_mask == 0 and a.collision_layer == 2)
	assert(a.reload_left == 0 and a.heal_left == 0 and a.total_ammunition() == ammo and a.medkits == meds)
	var initial_epoch: int = car.seats.epoch
	assert(not car.seats.enter(b, 0) and not car.seats.enter(a, 1))
	assert(car.seats.enter(b, 1))
	assert(not car.command(11, 0, 1, 0, false, initial_epoch))
	assert(car.command(11, 0, 1, 0, false, car.seats.epoch))
	car.reset_controls()
	var other := Vehicle.new()
	root.add_child(other)
	other.position = Vector3(8, 0, 0)
	other.grounded = true
	assert(not other.seats.enter(a, 0), "An actor cannot occupy two vehicles")
	var before: Vector3 = a.position
	a.move_input = Vector2(0, -1)
	a.move_step(1.0 / 60)
	assert(a.position == before)
	game.shoot(a)
	assert(not game.throw_grenade(a))
	a.reload_weapon()
	a.heal()
	assert(a.total_ammunition() == ammo and a.reload_left == 0 and a.heal_left == 0)
	car.position = Vector3(5, 0, 4)
	car.rotation.y = PI / 2
	car.seats.refresh()
	assert(a.position.is_equal_approx(car.to_global(car.seats.ANCHORS[0])))
	assert(is_equal_approx(a.yaw, PI / 2))
	car.position = Vector3.ZERO
	car.rotation = Vector3.ZERO
	car.seats.refresh()
	car.speed = 3
	assert(not car.seats.exit(a), "Moving vehicle cannot teleport occupants to the ground")
	car.speed = 0
	# The standing destination is clear, but a thin barrier blocks the path to it.
	wall = obstacle(Vector3(-1.25, 1, 0.1), Vector3(0.05, 2, 0.8))
	await sync_space()
	assert(car.seats.exit(a) and a.position.x > 1.5, "Blocked driver door must use a clear alternative")
	assert(not a.is_seated() and a.vehicle_seat == -1 and a.collision_mask == 7 and car.driver_id == 0)
	wall.queue_free()
	await process_frame
	await sync_space()
	assert(car.seats.exit(b) and b.position.x < -1.5, "A standing actor must block the occupied exit")
	a.position = Vector3(-2, 0, 0.1)
	b.position = Vector3(2, 0, 0.1)
	await sync_space()
	assert(car.seats.enter(a, 0) and car.seats.enter(b, 1))
	assert(not car.command(11, 0, 1, 0, false, initial_epoch), "Old seat generation cannot drive a reoccupied vehicle")
	var roofs: Array[Node] = []
	for point in car.seats.EXIT_POINTS:
		roofs.append(obstacle(point + Vector3.UP * 1.4, Vector3(0.8, 0.2, 0.8)))
	await sync_space()
	assert(car.seats.find_exit(a) == null, "Exits require standing headroom")
	for roof in roofs:
		roof.queue_free()
	await process_frame
	car.position.y = 0.8
	car.seats.refresh()
	await sync_space()
	assert(car.seats.find_exit(a) == null, "Exit must not drop an occupant from an elevated vehicle")
	car.position.y = 0
	car.seats.refresh()
	var slopes: Array[Node] = []
	for point in car.seats.EXIT_POINTS:
		var slope := obstacle(point + Vector3.UP * 0.2, Vector3(1, 0.1, 1))
		slope.rotation.x = PI / 4
		slopes.append(slope)
	await sync_space()
	assert(car.seats.find_exit(a) == null, "Exit must reject ground steeper than the actor can stand on")
	for slope in slopes:
		slope.queue_free()
	await process_frame
	var blockers: Array[Node] = []
	for point in car.seats.EXIT_POINTS:
		blockers.append(obstacle(point + Vector3.UP))
	await sync_space()
	assert(car.seats.find_exit(a) == null and not car.seats.exit(a))
	var driving_epoch: int = car.seats.epoch
	a.downed = true
	assert(not car.command(11, 0, 1, 0, false, driving_epoch), "Knock must reject input before the next cleanup tick")
	car.seats.refresh()
	assert(a.is_seated() and car.driver_id == 0, "Blocked knocked driver stays secured while controls are removed")
	assert(car.seats.epoch > driving_epoch)
	a.downed = false
	car.seats.refresh()
	assert(car.driver_id == 11 and not car.command(11, 0, 1, 0, false, driving_epoch), "Restored driver requires fresh seat generation")
	a.downed = true
	car.seats.refresh()
	for blocker in blockers:
		blocker.queue_free()
	await process_frame
	await sync_space()
	car.seats.refresh()
	assert(not a.is_seated() and a.downed)
	a.downed = false
	a.position = Vector3(-2, 0, 0.1)
	await sync_space()
	assert(car.seats.enter(a, 0))
	assert(car.seats.exit(a))
	assert(car.get_collision_exceptions().has(a))
	assert(car.seats.enter(a, 0), "Immediate re-entry remains valid")
	await sync_space()
	await physics_frame
	assert(car.get_collision_exceptions().has(a), "Pending exit must not undo a new seat exception")
	assert(car.seats.exit(a))
	await sync_space()
	await physics_frame
	assert(not car.get_collision_exceptions().has(a), "Exited actor must regain chassis collision")
	assert(car.collision_releases.is_empty())
	assert(car.seats.enter(a, 0))
	b.queue_free()
	await process_frame
	car.seats.refresh()
	assert(car.seats.occupant(1) == null)
	car.queue_free()
	await process_frame
	assert(not a.is_seated() and a.vehicle_seat == -1 and a.collision_mask == 7)
	far.position = Vector3(6, 0, 0.1)
	await sync_space()
	assert(other.seats.enter(far, 0))
	var disconnected_epoch: int = other.seats.epoch
	far.queue_free()
	await process_frame
	assert(not other.command(13, 0, 1, 0, false, disconnected_epoch))
	other.seats.refresh()
	assert(other.driver_id == 0 and other.seats.occupant(0) == null)
	print("VEHICLE_SEATS_PASS entry_los_distance=ok ownership=ok epoch=ok movement_combat_gates=ok follow=ok safe_exit=ok occupied_exit=ok blocked_exit=ok knock_brakes=ok disconnect_cleanup=ok vehicle_cleanup=ok")
	quit()
