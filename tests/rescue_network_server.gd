extends SceneTree
class RescueServer:
	extends "res://scripts/game.gd"
	var stage := 0
	var patient
	var helper
	var enemy
	var enemy_ally
	var completed_at := 0.0
	func reset_round() -> void:
		super.reset_round()
		phase_time = 8
	func begin_round() -> void:
		assert(sessions.size() == 4, "Four authenticated humans required")
		super.begin_round()
		var first: Array = teams.members[1].duplicate()
		var second: Array = teams.members[2].duplicate()
		first.sort()
		second.sort()
		patient = actors[first[0]]
		helper = actors[first[1]]
		enemy = actors[second[0]]
		enemy_ally = actors[second[1]]
		for actor in actors.values():
			actor.armor = 0
			if actor.is_bot:
				damage(actor, 10000, 0, true, false, "FIXTURE", null, true, true)
		loot.clear()
	func bot_input(_actor, _dt: float) -> void:
		pass
	func _physics_process(dt: float) -> void:
		super._physics_process(dt)
		if phase != "live":
			return
		if stage == 0 and elapsed > 1:
			damage(patient, 150, enemy.actor_id, true)
			assert(patient.downed and patient.alive and enemy.kills == 0)
			stage = 1
		elif stage == 1 and helper.revive_target == patient.actor_id and helper.revive_left < 4:
			damage(helper, 1, enemy.actor_id, true)
			assert(helper.revive_target == 0)
			add_event("RESCUE INTERRUPTED / HELPER HIT")
			stage = 2
		elif stage == 2 and helper.revive_target == patient.actor_id and helper.revive_left < 4:
			damage(patient, 10, enemy.actor_id, true)
			assert(patient.down_health == 90 and helper.revive_target == 0)
			add_event("RESCUE INTERRUPTED / PATIENT HIT")
			stage = 3
		elif stage == 3 and not patient.downed:
			assert(patient.health == 30 and patient.alive and helper.revive_target == 0)
			completed_at = elapsed
			stage = 4
		elif stage == 4 and elapsed > completed_at + 2:
			damage(enemy, 150, patient.actor_id, true)
			assert(enemy.downed)
			damage(enemy_ally, 150, patient.actor_id, true)
			assert(not enemy_ally.alive)
			rescue.update(self, 0)
			assert(not enemy.alive and patient.kills == 2)
			finish_round()
			assert(patient.rank == 1 and helper.rank == 1 and enemy.rank == 2 and enemy_ally.rank == 2)
			assert(result_outbox.is_empty(), "Duo persistence is not implemented yet")
			print("RESCUE_NETWORK_SERVER_PASS knock=ok two_damage_interrupts=ok revive=ok wipe=ok team_victory=ok")
			stage = 5
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := RescueServer.new()
	game.name = "Game"
	root.add_child(game)
