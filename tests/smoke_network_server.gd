extends SceneTree
class SmokeServer:
	extends "res://scripts/game.gd"
	func reset_round() -> void:
		super.reset_round()
		phase_time = 0.2
	func begin_round() -> void:
		super.begin_round()
		for actor in actors.values():
			if not actor.is_bot:
				actor.position = Vector3(0, 0.02, 20)
		loot.clear()
		loot[48] = {"kind": 4, "amount": 2.0, "p": Vector3(0, 0.1, 18.3)}
		next_loot_id = 49
	func bot_input(_actor, _dt: float) -> void:
		pass
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := SmokeServer.new()
	game.name = "Game"
	root.add_child(game)
