extends SceneTree

const History = preload("res://scripts/hit_history.gd")

class RewindGame:
	extends "res://scripts/game.gd"
	func shot_rewind_age(_actor) -> float:
		return 0.15

func _initialize() -> void:
	call_deferred("run")

func sync() -> void:
	await physics_frame
	await physics_frame

func run() -> void:
	assert(is_equal_approx(History.rewind_age(100), 0.15))
	assert(History.rewind_age(900) == 0.2)
	assert(History.rewind_age(-1) == 0 and History.rewind_age(NAN) == 0)
	assert(is_equal_approx(History.capsule_distance(Vector3(0, 1, 3), Vector3.FORWARD, Vector3.ZERO, 1.8), 2.62))
	assert(is_equal_approx(History.capsule_distance(Vector3(0, 3, 0), Vector3.DOWN, Vector3.ZERO, 1.8), 1.2))
	assert(History.capsule_distance(Vector3(0, 0.9, 0), Vector3.RIGHT, Vector3.ZERO, 1.8) == 0)
	assert(is_inf(History.capsule_distance(Vector3(2, 1, 3), Vector3.FORWARD, Vector3.ZERO, 1.8)))
	var game = RewindGame.new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.running = false
	game.sound.volume = 0
	game.elapsed = 10.2
	for other in game.actors.values():
		other.position = Vector3(105, 1, 100 + other.actor_id)
	var player = game.actors[1]
	var target = game.actors[-1]
	player.position = Vector3(0, 0.02, 20)
	target.position = Vector3(0, 0.02, 10)
	target.armor = 0
	game.hit_history.record(10.0, game.actors)
	game.hit_history.record(10.1, game.actors)
	target.position.x = 2
	target.crouch = true
	target.update_stance()
	game.hit_history.record(10.2, game.actors)
	await sync()
	var origin: Vector3 = player.eye_position()
	var present: Dictionary = game.trace_shot(player, origin, Vector3.FORWARD, 0)
	assert(present.is_empty() or present.collider != target, "Current ray misses moved, crouched target")
	var past: Dictionary = game.trace_shot(player, origin, Vector3.FORWARD, 0.15)
	assert(past.collider == target and past.headshot, "Past standing head is used")
	var unchanged: Vector3 = target.position
	var height: float = target.body_shape.shape.height
	game.shoot(player)
	assert(is_equal_approx(target.health, 100 - 23 * 1.65), "Real shot applies historical head damage")
	assert(target.position == unchanged and target.body_shape.shape.height == height and target.crouched, "No physics rewinding side effects")
	assert(game.ui.hit_until > Time.get_ticks_msec())
	var middle: Dictionary = game.hit_history.poses_at(10.15)
	assert(is_equal_approx(middle[-1].p.x, 1), "Position interpolates across history samples")
	assert(is_equal_approx(middle[-1].height, 1.8), "Stance changes discretely at sample boundary")
	var wall = game.world.block(Vector3(0, 1.5, 15), Vector3(5, 3, 0.5), "465a61")
	await sync()
	var blocked: Dictionary = game.trace_shot(player, origin, Vector3.FORWARD, 0.15)
	assert(blocked.collider != target, "Real wall blocks historical target")
	wall.queue_free()
	await sync()
	target.alive = false
	assert(game.hit_history.trace(10.05, origin, Vector3.FORWARD, 180, 1, game.actors).is_empty(), "Dead actors cannot receive historical hits")
	target.alive = true
	target.position.x = 20
	game.hit_history.record(10.3, game.actors)
	assert(not game.hit_history.poses_at(10.25).has(-1), "Teleport does not create swept target")
	for i in range(60):
		game.hit_history.record(11 + float(i) / 60, game.actors)
	assert(game.hit_history.samples.size() == History.MAX_SAMPLES)
	assert(game.hit_history.poses_at(10).is_empty(), "Expired history cannot be selected")
	game.clear_actors()
	assert(game.hit_history.samples.is_empty(), "Round cleanup removes historical identities")
	print("LAG_COMPENSATION_RULES_PASS cap=ok capsule=ok interpolation=ok stance=ok real_damage=ok headshot=ok wall=ok dead=ok teleport=ok bounded=ok round_reset=ok live_physics_unchanged=ok")
	game.queue_free()
	await process_frame
	quit()
