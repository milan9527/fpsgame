extends SceneTree

class RetentionGame:
	extends "res://scripts/game.gd"
	var heartbeat := {}
	var revoked := []
	func save_outbox() -> void:
		pass
	func http_call(_path: String, body: Dictionary, _internal := false, _method := HTTPClient.METHOD_POST) -> Dictionary:
		heartbeat = body
		return {"code": 200, "body": {"revoked": revoked}}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = RetentionGame.new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	assert(game.reconnect_grace_seconds == 0, "Unfinished reconnect must stay disabled by default")
	for scenario in ["expiry", "last_session", "revoked_heartbeat", "left", "revoked", "disabled"]:
		game.dedicated = false
		game.start_solo("duo")
		game.elapsed = 10
		game.sessions = {1: {"uid": "retained-fixture", "session_version": 3}}
		if scenario != "last_session":
			game.sessions[-1] = {"uid": "other-fixture", "session_version": 0}
		game.participants = {1: {"user_id": "retained-fixture", "team_id": 1, "rank": 0, "kills": 0}}
		game.reconnect_grace_seconds = 0 if scenario == "disabled" else 30
		if scenario == "left":
			game.sessions[1].leaving = true
		if scenario == "revoked":
			game.sessions[1].revoking = true
		var actor = game.actors[1]
		actor.move_input = Vector2.ONE
		actor.shooting = true
		actor.jump_requested = true
		actor.revive_target = -1
		var generation: String = game.match_id
		game.dedicated = true
		game.peer_disconnected(1)
		assert(not game.sessions.has(1))
		if scenario in ["left", "revoked", "disabled"]:
			assert(not game.actors.has(1) and game.retained_sessions.is_empty())
			continue
		assert(game.actors[1] == actor and actor.alive and game.phase == "live")
		game.peer_disconnected(1)
		assert(game.actors[1] == actor and actor.alive, "Duplicate disconnect callbacks must not kill the retained actor")
		assert(actor.move_input == Vector2.ZERO and not actor.shooting and not actor.jump_requested and actor.revive_target == 0)
		assert(game.retained_sessions[1].generation == generation)
		var durability: float = actor.health + actor.armor
		game.damage(actor, 20, 0, true)
		assert(actor.health < 100 and actor.health + actor.armor == durability - 20, "Retained actors must remain vulnerable with normal armor absorption")
		game.revoked = ["retained-fixture"] if scenario == "revoked_heartbeat" else []
		await game.report_room()
		assert("retained-fixture" in game.heartbeat.players and game.heartbeat.session_versions["retained-fixture"] == 3)
		if scenario != "revoked_heartbeat":
			var until: int = game.retained_sessions[1].until
			game.expire_retained_sessions(until - 1)
			assert(game.actors.has(1))
			game.expire_retained_sessions(until)
		assert(not game.actors.has(1) and game.retained_sessions.is_empty())
		if scenario == "last_session":
			assert(game.phase == "waiting" and game.match_id != generation and game.result_outbox.size() == 1)
			game.result_outbox.clear()
	game.dedicated = false
	game.local_recorded_id = game.match_id
	print("RECONNECT_RETENTION_PASS default_disabled=ok input_cleared=ok vulnerable=ok expiry=ok explicit_leave=excluded revoked=excluded heartbeat_revocation=ok last_session_recycle=ok")
	game.request_quit()
