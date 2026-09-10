extends SceneTree
class RecapServer:
	extends "res://scripts/game.gd"
	var tested := false
	func reset_round() -> void:
		super.reset_round()
		phase_time = 3
	func bot_input(_actor, _dt: float) -> void:
		pass
	func _physics_process(dt: float) -> void:
		super._physics_process(dt)
		if tested or phase != "live" or elapsed < 6 or sessions.size() != 2:
			return
		var victim
		var attacker
		for actor in actors.values():
			if not actor.is_bot:
				if actor.display_name == OS.get_environment("VICTIM_USERNAME"):
					victim = actor
				else:
					attacker = actor
		if victim == null or attacker == null:
			return
		tested = true
		attacker.weapon = 2
		victim.health = 42
		victim.armor = 15
		damage(victim, 500, attacker.actor_id, false, true)
		print("DEATH_RECAP_SERVER_SENT victim_only=true")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := RecapServer.new()
	game.name = "Game"
	root.add_child(game)
