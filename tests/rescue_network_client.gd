extends SceneTree
class InvitedClient:
	extends "res://scripts/game.gd"
	func sign_in(_username: String, _password: String, _register: bool, endpoint: String, _mode := "solo") -> void:
		connection_attempt += 1
		api_url = endpoint
		token = OS.get_environment("TEST_PARTY_TOKEN")
		token_origin = endpoint
		ui.party_lobby.identity = OS.get_environment("TEST_PARTY_UID")
		ui.busy = true
		var admission: Dictionary = JSON.parse_string(OS.get_environment("TEST_PARTY_ADMISSION"))
		connect_admission(admission, endpoint, token, "duo", connection_attempt)
var game
var deadline: int
func _initialize() -> void:
	call_deferred("run")
func interact() -> void:
	Input.action_press("loot")
	await physics_frame
	await physics_frame
	Input.action_release("loot")
func run() -> void:
	game = InvitedClient.new() if OS.has_environment("TEST_PARTY_ADMISSION") else load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	deadline = Time.get_ticks_msec() + 65000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
	print("RESCUE_CLIENT_ADMITTED")
	game.bot_client = false
	var patient_id := 0
	var helper_id := 0
	while patient_id == 0:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
		if game.phase != "live" or game.actors.size() != 16:
			continue
		var pair: Array = []
		for actor in game.actors.values():
			if actor.team_id == 1 and actor.actor_id > 0:
				pair.append(actor.actor_id)
		if pair.size() == 2:
			pair.sort()
			patient_id = pair[0]
			helper_id = pair[1]
	var patient = game.actors[patient_id]
	var helper = game.actors[helper_id]
	var voice_case := OS.get_environment("TEST_VOICE_RELAY") == "1"
	var voice_senders := {}
	var voice_parity := {}
	var voice_payload := PackedByteArray()
	var voice_sequence := 0
	var voice_due := 0
	if voice_case:
		var samples := PackedVector2Array()
		samples.resize(320)
		samples.fill(Vector2.ONE * (0.1 + 0.01 * (game.local_id % 7)))
		voice_payload = load("res://scripts/voice_codec.gd").encode(samples)
		game.voice_packet_received.connect(func(sender: int, sequence: int, packet: PackedByteArray):
			assert(sender != game.local_id and game.actors.has(sender))
			assert(game.actors[sender].team_id == game.actors[game.local_id].team_id)
			var decoded: PackedVector2Array = load("res://scripts/voice_codec.gd").decode(packet)
			assert(decoded.size() == 320 and absf(decoded[0].x - (0.1 + 0.01 * (sender % 7))) < 0.0001)
			assert(sequence >= 0 and sequence < 100000)
			voice_senders[sender] = int(voice_senders.get(sender, 0)) + 1
			voice_parity[sequence % 2] = true
		)
	var ping_case := OS.get_environment("TEST_TEAM_PINGS") == "1"
	var observed_team_pings := false
	if ping_case:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = game.ui.tactical_map.world_to_map(Vector2(10 + 10 * int(OS.get_environment("TEST_PING_SLOT")), 20))
		game.ui.tactical_map._gui_input(click)
	var observed_knock := false
	var observed_down_animation := false
	var observed_progress := false
	var observed_revive := false
	var interrupts := 0
	var active := false
	var requests := 0
	var request_due := 0
	var observed_team_view := false
	var observed_downed_hud := false
	var revoke_case := OS.get_environment("TEST_REVOKE_MEMBER") == "1"
	var observed_departure := false
	while game.phase != "finished":
		assert(Time.get_ticks_msec() < deadline, "Network rescue scenario timed out")
		await process_frame
		if voice_case and Time.get_ticks_msec() >= voice_due:
			voice_due = Time.get_ticks_msec() + 40
			game.submit_voice.rpc_id(1, game.network_round_id, voice_sequence + 1, voice_payload)
			game.submit_voice.rpc_id(1, game.network_round_id, voice_sequence, voice_payload)
			# A forged round must never produce a receiver notification.
			game.submit_voice.rpc_id(1, "old-round", voice_sequence + 100000, voice_payload)
			voice_sequence += 2
		if ping_case and game.ui.tactical_map.shared_pings.size() == 2:
			for marker in game.ui.tactical_map.shared_pings:
				assert(game.actors.has(marker.id) and game.actors[marker.id].team_id == game.actors[game.local_id].team_id)
				assert(marker.remaining > 0 and marker.remaining <= 20)
			observed_team_pings = true
		if revoke_case and not game.running:
			assert(observed_knock and observed_progress and observed_revive and interrupts == 2)
			assert(game.token.is_empty() and not game.online)
			print("REVOKED_MEMBER_CLIENT_PASS rescue_observed=ok token_cleared=ok connection_closed=ok")
			game.request_quit()
			return
		if revoke_case and not is_instance_valid(patient):
			observed_departure = true
			continue
		if game.local_id == helper_id and "DOWNED" in game.ui.team_label.text:
			observed_downed_hud = true
		if game.local_id == patient_id and not patient.alive and game.spectator.active:
			assert(game.spectator.target_id == helper_id)
			observed_team_view = true
		if patient.downed:
			observed_knock = true
			assert(patient.alive and patient.health == 0 and patient.bleed_left > 0)
			if patient.character_animation.active_clip in ["DownedIdle", "DownedCrawl"]:
				assert(not patient.third_person_gun.visible)
				observed_down_animation = true
		if helper.revive_target == patient_id:
			observed_progress = true
			active = true
			assert(helper.revive_left > 0 and helper.revive_left <= 5)
		elif active:
			active = false
			if patient.downed:
				interrupts += 1
				request_due = Time.get_ticks_msec() + 200
		if observed_knock and not patient.downed and patient.alive and patient.health == 30:
			observed_revive = true
		if game.local_id == helper_id and patient.downed and helper.revive_target == 0 and requests == interrupts and Time.get_ticks_msec() >= request_due:
			requests += 1
			await interact()
	assert(observed_knock and observed_progress and observed_revive and interrupts == 2)
	assert(observed_down_animation)
	if voice_case:
		assert(voice_senders.size() == 1 and voice_senders.values()[0] >= 10 and voice_parity.size() == 2)
		print("VOICE_RELAY_CLIENT_PASS team_sender_only=ok synthetic_audio_decoded=ok")
	if ping_case:
		assert(observed_team_pings)
		print("TEAM_PINGS_NETWORK_CLIENT_PASS map_click=ok own_and_ally=ok enemies_excluded=ok")
	assert((revoke_case or patient.rank == 1) and helper.rank == 1 and helper.kills == 2)
	await process_frame
	await process_frame
	if revoke_case and game.local_id == helper_id:
		assert(observed_departure and game.ui.team_markers.is_empty() and game.ui.tactical_map.teammates.is_empty())
	else:
		assert(game.ui.team_markers.size() == 1 and game.ui.tactical_map.teammates.size() == 1)
		var marker: Dictionary = game.ui.team_markers[0]
		assert(marker.id != game.local_id and game.actors[marker.id].team_id == game.actors[game.local_id].team_id)
	if game.local_id == patient_id:
		assert(observed_team_view and game.spectator.target_id == helper_id)
	if game.actors[game.local_id].team_id == 2:
		assert(game.spectator.active and game.spectator.target_id == 0 and game.spectator.candidates(game.actors).is_empty())
		assert("TEAM ELIMINATED" in game.ui.spectator_label.text)
	for actor in game.actors.values():
		if actor.actor_id > 0 and actor.team_id == 2:
			assert(not actor.alive and actor.rank == 2)
	if game.local_id == helper_id:
		assert(requests == 3 and observed_downed_hud)
	print("RESCUE_NETWORK_CLIENT_PASS peer=%d knock=replicated progress=replicated interrupts=2 revived=replicated team_results=replicated team_spectator=ok" % game.local_id)
	await create_timer(1).timeout
	if OS.get_environment("TEST_RETURN_TO_PARTY") == "1":
		assert(game.ui.return_to_party_button.visible)
		game.ui.return_to_party_button.pressed.emit()
		while not game.ui.party_lobby.visible or game.ui.party_lobby.busy or not game.ui.party_lobby.known:
			assert(Time.get_ticks_msec() < deadline)
			await process_frame
		assert(not game.online and not game.running)
		assert(game.token == OS.get_environment("TEST_PARTY_TOKEN"))
		var admission: Dictionary = JSON.parse_string(OS.get_environment("TEST_PARTY_ADMISSION"))
		assert(game.ui.party_lobby.party.id == admission.party_id)
		assert(game.ui.party_lobby.party.members.size() == 2)
		print("POST_MATCH_PARTY_RETURN_PASS connection_closed=ok same_party=ok token_retained=ok")
	game.request_quit()
