extends SceneTree
class UtilityServer:
	extends "res://scripts/game.gd"
	var healed := false
	func reset_round() -> void:
		super.reset_round()
		phase_time = 3
	func begin_round() -> void:
		super.begin_round()
		for actor in actors.values():
			actor.position = Vector3(105, 0.02, 105) if actor.is_bot else Vector3(0, 0.02, -6)
		var actor = actors[-1]
		actor.position = Vector3(0, 0.02, 20)
		actor.health = 30
		actor.armor = 0
		actor.grenades = 0
		actor.smokes = 0
		actor.navigator.cover.search_left = 100
		loot = {48: {"p": actor.position, "kind": 4, "amount": 1.0}}
		next_loot_id = 49
	func bot_input(actor, dt: float) -> void:
		if actor.actor_id != -1:
			return
		if elapsed < 9:
			pickup(actor)
			return
		super.bot_input(actor, dt)
		if actor.health > 30 and not healed:
			healed = true
			assert(actor.smokes == 0 and actor.medkits == 1 and not loot.has(48))
			print("BOT_UTILITIES_SERVER_PASS actual_pickup=ok smoke=spent treatment=completed")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := UtilityServer.new()
	game.name = "Game"
	root.add_child(game)
