extends SceneTree

class TestGame:
	extends "res://scripts/game.gd"
	func save_outbox() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := TestGame.new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("duo")
	game.elapsed = 10
	var patient = game.actors[1]
	var rescuer = game.actors[-1]
	var enemy = game.actors[-2]
	game.participants = {
		1: {"user_id": "patient-fixture", "team_id": 1, "rank": 0, "kills": 0},
		-1: {"user_id": "rescuer-fixture", "team_id": 1, "rank": 0, "kills": 0}}
	# Preserve another session so normal last-client room cleanup does not run.
	game.sessions = {1: {"uid": "patient-fixture"}, -1: {"uid": "rescuer-fixture"}}
	assert(game.departure_reason(99) == "unauthenticated")
	assert(game.departure_reason(-1) == "connection_lost")
	game.sessions[-1].leaving = true
	assert(game.departure_reason(-1) == "left")
	game.sessions[-1].revoking = true
	assert(game.departure_reason(-1) == "revoked", "Revocation must win over client departure acknowledgement")
	game.sessions[-1].erase("leaving")
	game.sessions[-1].erase("revoking")
	game.damage(patient, 10000, enemy.actor_id, true)
	assert(patient.downed and patient.alive)
	await physics_frame
	assert(game.rescue.interact(game, rescuer))
	assert(rescuer.revive_target == 1)
	game.dedicated = true
	game.peer_disconnected(-1)
	assert(not game.actors.has(-1) and not game.sessions.has(-1))
	assert(game.teams.assignments[-1] == 1, "Disconnect must not erase match team identity")
	game.rescue.update(game, 0.016)
	assert(not patient.alive and patient.rank == 8)
	assert(game.participants[1].rank == 8 and game.participants[-1].rank == 8)
	assert(enemy.kills == 1, "The original knock receives one elimination")
	game.rescue.update(game, 0.016)
	assert(enemy.kills == 1)
	game.finish_round()
	assert(game.result_outbox.size() == 1)
	var results: Array = game.result_outbox[0].players
	assert(results.size() == 2)
	for result in results:
		assert(result.team_id == 1 and result.rank == 8)
	game.queue_free()
	await process_frame
	print("DUO_DISCONNECT_RULES_PASS rescue_interrupted=ok orphan_downed_wiped=ok shared_rank=8 knock_credit_once=ok disconnected_result=retained")
	quit()
