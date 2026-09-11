extends SceneTree
class RescueServer:
	extends "res://scripts/game.gd"
	var stage := 0
	var patient
	var helper
	var enemy
	var enemy_ally
	var completed_at := 0.0
	var departed_id := 0
	func reset_round() -> void:
		super.reset_round()
		phase_time = 14 if OS.get_environment("TEST_INVITED_PARTIES") == "1" else 8
	func begin_round() -> void:
		assert(sessions.size() == 4, "Four authenticated humans required")
		super.begin_round()
		if OS.get_environment("TEST_INVITED_PARTIES") == "1":
			var ordered: Array = sessions.keys()
			assert(sessions[ordered[0]].party_id == sessions[ordered[2]].party_id)
			assert(sessions[ordered[1]].party_id == sessions[ordered[3]].party_id)
			assert(sessions[ordered[0]].party_id != sessions[ordered[1]].party_id)
			assert(actors[ordered[0]].team_id == actors[ordered[2]].team_id)
			assert(actors[ordered[1]].team_id == actors[ordered[3]].team_id)
			assert(actors[ordered[0]].team_id != actors[ordered[1]].team_id)
			print("INVITED_INTERLEAVED_TEAMS_PASS")
		var first: Array = teams.members[1].duplicate()
		var second: Array = teams.members[2].duplicate()
		first.sort()
		second.sort()
		patient = actors[first[0]]
		departed_id = patient.actor_id
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
			if OS.get_environment("TEST_REVOKE_MEMBER") == "1":
				print("READY_FOR_MEMBER_REVOCATION uid=" + sessions[departed_id].uid)
				stage = 40
				return
			damage(patient, 150, 0, true)
			damage(patient, 150, 0, true)
			assert(not patient.alive and helper.alive)
			completed_at = elapsed
			stage = 5
		elif stage == 40 and not actors.has(departed_id):
			assert(not sessions.has(departed_id) and helper.alive)
			assert(participants[departed_id].rank == 0)
			completed_at = elapsed
			stage = 5
		elif stage == 5 and elapsed > completed_at + 2:
			damage(enemy, 150, helper.actor_id, true)
			assert(enemy.downed)
			damage(enemy_ally, 150, helper.actor_id, true)
			assert(not enemy_ally.alive)
			rescue.update(self, 0)
			assert(not enemy.alive and helper.kills == 2)
			finish_round()
			assert(participants[departed_id].rank == 1 and helper.rank == 1 and enemy.rank == 2 and enemy_ally.rank == 2)
			assert(result_outbox.size() == 1 and result_outbox[0].mode == "duo")
			# Exercise disk serialization and reload before the normal sender.
			result_outbox.clear()
			load_outbox()
			assert(result_outbox.size() == 1)
			print("RESCUE_NETWORK_SERVER_PASS match_id=%s knock=ok two_damage_interrupts=ok revive=ok wipe=ok team_victory=ok" % match_id)
			stage = 6
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game := RescueServer.new()
	game.name = "Game"
	root.add_child(game)
