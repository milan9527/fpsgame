extends SceneTree
class GripServer:
	extends "res://scripts/game.gd"
	func reset_round() -> void:
		super.reset_round()
		phase_time = 3.0
	func begin_round() -> void:
		super.begin_round()
		var index := 0
		for actor in actors.values():
			if not actor.is_bot:
				actor.position = Vector3(index * 2, 0.02, 20)
				index += 1
		next_loot_id = 49
		loot = {48: {"p": Vector3(0, 0.1, 18.3), "kind": 5, "amount": 2.0}}
	func bot_input(_actor, _dt: float) -> void:
		pass
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := GripServer.new()
	game.name = "Game"
	root.add_child(game)
