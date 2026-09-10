extends SceneTree
class FallServer:
	extends "res://scripts/game.gd"
	func reset_round() -> void:
		super.reset_round()
		phase_time = 0.2
	func begin_round() -> void:
		super.begin_round()
		elapsed = 10
		for actor in actors.values():
			if not actor.is_bot:
				actor.position = Vector3(0, 4.5, 20)
				actor.armor = 100
	func bot_input(_actor, _dt: float) -> void:
		pass
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := FallServer.new()
	game.name = "Game"
	root.add_child(game)
