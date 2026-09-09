extends SceneTree

class SupplyServer:
	extends "res://scripts/game.gd"

	func reset_round() -> void:
		super.reset_round()
		phase_time = 0.2

	func begin_round() -> void:
		super.begin_round()
		for actor in actors.values():
			if not actor.is_bot:
				actor.position = Vector3(0, 0.02, 20)
				actor.reserve = 295
				actor.medkits = 0
		loot = {7: {"p": Vector3(0, 0.1, 18.3), "kind": 0}, 8: {"p": Vector3(1, 0.1, 18.3), "kind": 1}}

	func bot_input(_actor, _dt: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := SupplyServer.new()
	game.name = "Game"
	root.add_child(game)
