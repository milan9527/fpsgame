extends SceneTree

class ObservedGame:
	extends "res://scripts/game.gd"
	var visibility_calls := 0
	func visible_target(actor, other) -> bool:
		visibility_calls += 1
		return super.visible_target(actor, other)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := ObservedGame.new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	game.zone_state = {}
	game.zone = 110
	var actor = game.actors[-1]
	var target = game.actors[1]
	for other in game.actors.values():
		if other != actor and other != target:
			other.alive = false
			other.position = Vector3(105, 0.02, 105)
	actor.position = Vector3(5, 0.02, 4)
	target.position = Vector3(0, 0.02, -12)
	actor.health = 100
	actor.ammo = 15
	actor.lean = 0
	actor.yaw = 1.5
	actor.bot_think = 0
	for i in range(120):
		await physics_frame
		if game.world.navigation_ready():
			break
	assert(game.world.navigation_ready())
	assert(game.visible_target(actor, target), "Fixture needs a clear live physics ray")
	game.visibility_calls = 0
	game.bot_input(actor, 1.0 / 60)
	assert(actor.target_id == target.actor_id and actor.shooting)
	assert(game.visibility_calls == 1, "Selection and shooting share one live trace")
	game.visibility_calls = 0
	game.bot_input(actor, 1.0 / 60)
	assert(actor.shooting and game.visibility_calls == 1, "Next tick must trace again")
	actor.lean = 0.8
	actor.yaw = 1.5
	actor.bot_think = 0
	game.visibility_calls = 0
	game.bot_input(actor, 1.0 / 60)
	assert(actor.shooting and game.visibility_calls == 2, "Changed leaning origin needs a fresh trace")
	actor.lean = 0
	game.world.block(Vector3(2.5, 2, -4), Vector3(8, 4, 2), "657477")
	await physics_frame
	await physics_frame
	actor.bot_think = 1
	game.visibility_calls = 0
	game.bot_input(actor, 1.0 / 60)
	assert(not actor.shooting and game.visibility_calls == 1, "New cover cannot reuse previous-tick visibility")
	print("BOT_VISIBILITY_SAME_TICK_PASS selection=1 next_tick=1 changed_eye=2 new_cover=blocked")
	game.request_quit()
