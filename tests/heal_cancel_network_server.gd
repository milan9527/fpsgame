extends SceneTree
class HealServer:
	extends "res://scripts/game.gd"
	func reset_round() -> void:
		super.reset_round()
		phase_time = 3
	func begin_round() -> void:
		super.begin_round()
		for actor in actors.values():
			actor.position = Vector3(105, 0.02, 105) if actor.is_bot else Vector3(0, 0.02, 20)
			if not actor.is_bot:
				actor.health = 30
				actor.armor = 0
		loot.clear()
	func bot_input(_actor, _dt: float) -> void:
		pass
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := HealServer.new()
	game.name = "Game"
	root.add_child(game)
