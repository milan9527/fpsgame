extends SceneTree
const Pose = preload("res://scripts/seated_hit_pose.gd")

func _initialize() -> void:
	call_deferred("run")

func sync() -> void:
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
	var shooter = game.actors[1]
	var target = game.actors[-1]
	target.armor = 0
	var car = game.vehicle_fleet.spawn(game, Vector3.ZERO)
	await sync()
	for _i in range(5):
		car.simulate(1.0 / 60)
	target.position = Vector3(-1.65, 0.04, 0.1)
	assert(car.seats.enter(target, 0))
	var pose: Dictionary = Pose.capture(target)
	var head: Dictionary = pose.boxes.filter(func(box): return box.headshot)[0]
	var center: Vector3 = pose.p + pose.basis * (head.transform * head.bounds.get_center())
	var origin := center + Vector3.LEFT * 6
	shooter.position = origin - Vector3.UP * shooter.eye_height()
	shooter.yaw = -PI / 2
	shooter.pitch = 0
	shooter.aiming = true
	await sync()
	var hit: Dictionary = game.trace_shot(shooter, origin, Vector3.RIGHT, 0)
	assert(hit.collider == target and hit.headshot, "Open cockpit must expose the actual seated helmet")
	assert(game.visible_target(shooter, target), "Bots must see exposed seated bodies through the same geometry")
	game.hit_history.record(19.9, game.actors)
	game.hit_history.record(20, game.actors)
	var past: Dictionary = game.trace_shot(shooter, origin, Vector3.RIGHT, 0.1)
	assert(past.collider == target and past.headshot)
	assert(past.position.distance_to(hit.position) < 0.001, "Direct and rewind share seated hit geometry")
	var health: float = target.health
	game.shoot(shooter)
	assert(is_equal_approx(target.health, health - 23 * 1.65))
	assert(car.health == 600, "A clean cockpit hit must not also damage the hull")
	var hood: Dictionary = game.trace_shot(shooter, Vector3(0, 0.93, -5), Vector3.BACK, 0)
	assert(hood.collider == car and hood.part == "Hood")
	# The movement capsule extends below the seated body; it must not be hit.
	var low: Dictionary = game.trace_shot(shooter, Vector3(-5, 0.15, 0.1), Vector3.RIGHT, 0)
	assert(low.is_empty() or low.collider != target)
	var wall = game.world.block((origin + center) / 2, Vector3(0.2, 2, 2), "465a61")
	await sync()
	assert(game.trace_shot(shooter, origin, Vector3.RIGHT, 0).collider != target)
	assert(game.trace_shot(shooter, origin, Vector3.RIGHT, 0.1).collider != target)
	assert(not game.visible_target(shooter, target))
	wall.queue_free()
	await sync()
	car.position.x += 1
	car.seats.sync_actor(target, 0)
	game.elapsed = 20.1
	game.hit_history.record(20.1, game.actors)
	await sync()
	var current: Dictionary = game.trace_shot(shooter, origin, Vector3.RIGHT, 0)
	past = game.trace_shot(shooter, origin, Vector3.RIGHT, 0.1)
	assert(current.collider == target and past.collider == target)
	assert(is_equal_approx(current.position.x - past.position.x, 1))
	var saved: Vector3 = car.position
	assert(target.position.is_equal_approx(car.to_global(car.seats.ANCHORS[0])))
	assert(car.position == saved, "Rewind never relocates live vehicle bodies")
	game.queue_free()
	await process_frame
	print("VEHICLE_SHOOTING_PASS cockpit=ok actual_head_damage=ok no_double_damage=ok hood=ok standing_capsule_excluded=ok wall=ok moving_rewind=ok")
	quit()
