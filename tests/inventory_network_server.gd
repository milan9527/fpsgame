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
		loot.clear()
		var victim = actors[-1]
		victim.position = Vector3(0, 0.02, 18.3)
		victim.magazines = PackedInt32Array([7, 2, 1])
		victim.reserve = 27
		victim.medkits = 3
		victim.grenades = 2
		damage(victim, 10000, 0, true)

	func bot_input(_actor, _dt: float) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := SupplyServer.new()
	game.name = "Game"
	root.add_child(game)
