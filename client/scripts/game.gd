extends Node3D

const BlastEffect = preload("res://scripts/blast_effect.gd")
const Grenade = preload("res://scripts/grenade.gd")
const Actor = preload("res://scripts/actor.gd")
const World = preload("res://scripts/world.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/sound.gd")
const Spectator = preload("res://scripts/spectator.gd")
const LocalProfile = preload("res://scripts/local_profile.gd")
const BotNavigator = preload("res://scripts/bot_navigator.gd")
const HitHistory = preload("res://scripts/hit_history.gd")
const SupplyRules = preload("res://scripts/supply_rules.gd")
var hit_history := HitHistory.new()
var rewind_peers := {}
const PORT := 27015
const MAX_PLAYERS := 16
const ROUND_SECONDS := 300.0
var world
var ui
var sound
var spectator
var local_profile
var local_outbox: Array[Dictionary] = []
var local_recorded_id := ""
var actors: Dictionary = {}
var sessions: Dictionary = {}
var pending: Dictionary = {}
var participants: Dictionary = {}
var loot: Dictionary = {}
var next_loot_id := 48
var grenades: Dictionary = {}
var next_grenade_id := 1
var grenade_tombstones: Dictionary = {}
var last_loot_hash := 0
var events: Array = []
var last_eliminated_name := ""
var dedicated := false
var online := false
var running := false
var phase := "standby"
var phase_time := 0.0
var elapsed := 0.0
var zone := 110.0
var zone_tick := 0.0
var net_tick := 0.0
var local_id := 1
var sequence := 0
var action_latch: Dictionary = {}
var inventory_pointer_guard := false
var token := ""
var token_origin := ""
var ticket := ""
var api_url := "http://127.0.0.1:8000"
var server_key := ""
var match_id := ""
var network_round_id := ""
var result_outbox: Array = []
var submitting := false
var retry_time := 0.0
var lobby_camera: Camera3D
var rng := RandomNumberGenerator.new()
var smoke := false
var smoke_frames := 0
var bot_client := false
var audio_test := false
var shutdown_requested := false
var round_client := false
var bot_test_timer := 0.0
var test_start_position := Vector3.ZERO
var test_moved := false
var test_fired := false
var test_crouched := false
var test_recoil := false
var test_remote_crouch := false
var test_remote_animation := false
var test_grenade_seen := false
var test_grenade_exploded := false
var test_throw_sent := false
var test_switch_stage := 0
var test_remote_weapons := {}
var test_magazines := false
var test_menu_started := false
var test_menu_done := false
var test_menu_time := 0.0
var authenticated_at := 0
var build_info: Dictionary = {}
var room_id := ""
var room_instance := ""
var room_revision := 0
var room_port := PORT
var room_heartbeat_busy := false
var room_heartbeat_due := 0
var room_heartbeat_success := -100000
var room_heartbeat_signature := ""
var room_heartbeat_attempt := -100000
var connection_attempt := 0
var admission_ticket := ""
var admission_origin := ""
var admission_token := ""

func _ready() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://protocol.json"))
	if not manifest is Dictionary or not manifest.has("protocol") or not manifest.has("content_revision"):
		push_error("Missing or invalid build manifest")
		request_quit(1)
		return
	build_info = manifest
	build_info.protocol = int(build_info.protocol)
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	dedicated = "--server" in args
	smoke = "--smoke" in args
	bot_client = "--bot-client" in args
	audio_test = bot_client and OS.get_environment("TEST_AUDIO") == "1"
	round_client = "--round-client" in args
	if OS.has_environment("API_URL"):
		api_url = OS.get_environment("API_URL")
	server_key = OS.get_environment("SERVER_SECRET")
	setup_input()
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	lobby_camera = Camera3D.new()
	add_child(lobby_camera)
	lobby_camera.position = Vector3(0, 60, 80)
	lobby_camera.look_at(Vector3.ZERO)
	lobby_camera.current = true
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): leave("Unable to reach game server"))
	multiplayer.server_disconnected.connect(func(): leave("Connection to server lost"))
	if dedicated:
		# All gameplay is server-authoritative. Do not relay peer join/leave or
		# client-to-client packets through SceneMultiplayer's internal channel.
		multiplayer.server_relay = false
		start_server()
	else:
		get_tree().auto_accept_quit = false
		if not smoke and not "--capture-game" in args and not "--capture-menu" in args:
			local_profile = LocalProfile.new()
		spectator = Spectator.new()
		add_child(spectator)
		sound = Sound.new()
		sound.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(sound)
		ui = Interface.new()
		add_child(ui)
		sound.volume = 0.0 if smoke or bot_client else ui.volume
		if audio_test:
			sound.volume = 0.65
		ui.volume_changed.connect(func(v): sound.volume = v)
		ui.pause_changed.connect(change_pause)
		ui.connection_cancel_requested.connect(func(): leave("Connection cancelled."))
		ui.inventory_changed.connect(func(_enabled): action_latch.clear(); inventory_pointer_guard = true)
		ui.inventory.pickup_requested.connect(inventory_pickup)
		ui.inventory.equipment_requested.connect(inventory_equipment)
		ui.inventory.drop_requested.connect(inventory_drop)
		ui.solo_requested.connect(start_solo)
		ui.leaderboard_requested.connect(show_leaderboard)
		ui.online_requested.connect(sign_in)
		ui.leave_requested.connect(func(): leave())
		ui.quit_requested.connect(request_quit)
		ui.quit_without_save_requested.connect(func(): request_quit(0, true))
		ui.local_history_requested.connect(show_local_history)
		if smoke:
			call_deferred("start_solo")
		elif "--capture-game" in args:
			call_deferred("start_solo")
			call_deferred("capture_frame")
		elif "--capture-menu" in args:
			call_deferred("capture_frame")
		elif bot_client:
			call_deferred("sign_in", OS.get_environment("TEST_USERNAME"), OS.get_environment("TEST_PASSWORD"), false, api_url)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not online and not dedicated and ui != null:
		ui.set_pause(true)

func request_quit(code := 0, discard_local := false) -> void:
	if shutdown_requested:
		return
	save_local_operation()
	flush_local_results()
	if not discard_local and not local_outbox.is_empty() and ui != null:
		leave("Local results could not be saved. Retry before exiting.")
		show_local_history()
		ui.local_exit_button.visible = true
		return
	shutdown_requested = true
	connection_attempt += 1
	await cancel_admission()
	get_tree().paused = false
	running = false
	if sound != null:
		sound.volume = 0
		sound.reset_round()
		if online and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			# Keep polling the reliable channel until the server sees the leave,
			# rather than destroying ENet after one potentially lost packet.
			leave_operation.rpc_id(1)
			var deadline := Time.get_ticks_msec() + 2000
			while multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec() < deadline:
				await get_tree().process_frame
			if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				multiplayer.multiplayer_peer.disconnect_peer(1)
		# Stop requests and deferred frees need a mixer cycle before engine teardown.
		await get_tree().process_frame
		await get_tree().create_timer(0.15).timeout
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().quit(code)

func setup_input() -> void:
	var keys := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "jump": KEY_SPACE, "reload": KEY_R, "loot": KEY_E, "heal": KEY_H, "throw": KEY_G, "weapon1": KEY_1, "weapon2": KEY_2, "weapon3": KEY_3, "pause": KEY_ESCAPE, "inventory": KEY_B, "scoreboard": KEY_TAB, "spectate_previous": KEY_Q, "spectate_next": KEY_E}
	for action in keys:
		InputMap.add_action(action)
		var e := InputEventKey.new()
		e.physical_keycode = keys[action]
		InputMap.action_add_event(action, e)
	for action in ["fire", "aim"]:
		InputMap.add_action(action)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, e)

func start_server() -> void:
	if server_key.length() < 32:
		push_error("SERVER_SECRET must contain at least 32 characters")
		request_quit(1)
		return
	var response: Dictionary = await http_call("/internal/build/check", build_info, true)
	if response.code != 200 or not compatible_build(response.body):
		push_error("Server build is incompatible with operations service")
		request_quit(1)
		return
	world.prepare_navigation()
	var peer := ENetMultiplayerPeer.new()
	var listen_port := int(OS.get_environment("GAME_PORT")) if OS.has_environment("GAME_PORT") else PORT
	var error := peer.create_server(listen_port, MAX_PLAYERS + 8)
	if error != OK:
		push_error("Cannot bind game port: " + str(error))
		request_quit(1)
		return
	multiplayer.multiplayer_peer = peer
	online = true
	running = true
	phase = "waiting"
	match_id = uuid4()
	room_port = listen_port
	room_id = OS.get_environment("GAME_ROOM_ID") if OS.has_environment("GAME_ROOM_ID") else "room-" + str(listen_port)
	room_instance = uuid4()
	# A restarted process waits for the previous instance's 12s lease to expire.
	for attempt in range(8):
		if await report_room():
			break
		await get_tree().create_timer(2, true, false, true).timeout
	if room_heartbeat_success < 0:
		push_error("Room registration failed")
		request_quit(1)
		return
	load_outbox()
	print("SERVER_READY udp=" + str(listen_port) + " relay=" + str(multiplayer.server_relay) + " room=" + room_id)

func room_signature() -> String:
	return match_id + "/" + phase + "/" + str(sessions.keys())

func report_room() -> bool:
	if room_heartbeat_busy:
		return false
	room_heartbeat_busy = true
	room_heartbeat_attempt = Time.get_ticks_msec()
	room_revision += 1
	var signature := room_signature()
	var players: Array = []
	for session in sessions.values():
		players.append(session.uid)
	var payload := build_info.duplicate()
	payload.merge({"room_id": room_id, "instance_id": room_instance, "generation": match_id, "revision": room_revision, "host": OS.get_environment("GAME_PUBLIC_HOST") if OS.has_environment("GAME_PUBLIC_HOST") else "127.0.0.1", "port": room_port, "capacity": MAX_PLAYERS, "phase": phase, "players": players})
	var response: Dictionary = await http_call("/internal/rooms/heartbeat", payload, true)
	room_heartbeat_busy = false
	room_heartbeat_due = Time.get_ticks_msec() + 2000
	if response.code != 200:
		return false
	room_heartbeat_signature = signature
	room_heartbeat_success = Time.get_ticks_msec()
	return true

func start_solo() -> void:
	connection_attempt += 1
	cancel_admission()
	if online:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().paused = false
	save_local_operation()
	flush_local_results()
	world.prepare_navigation()
	online = false
	running = true
	local_id = 1
	sessions = {1: {"username": "YOU", "uid": ""}}
	reset_round()
	begin_round()
	ui.show_game()

func clear_actors() -> void:
	hit_history.clear()
	rewind_peers.clear()
	if sound != null:
		sound.reset_round()
	if spectator != null:
		spectator.reset()
		lobby_camera.current = true
		if ui != null:
			ui.set_spectator(false, "", 0)
	clear_grenades()
	for actor in actors.values():
		remove_child(actor)
		actor.queue_free()
	actors.clear()

func reset_round() -> void:
	clear_actors()
	participants.clear()
	events.clear()
	last_eliminated_name = ""
	loot.clear()
	next_loot_id = 48
	elapsed = 0
	zone = 110
	zone_tick = 0
	world.set_zone(zone)
	# Preserve the generation of waiting-room reservations when the first player
	# starts the lobby. Later rounds always get a fresh generation.
	if phase != "waiting" or match_id.is_empty():
		match_id = uuid4()
	var index := 0
	for id in sessions:
		var actor = spawn_actor(id, sessions[id].username, false, spawn_position(index))
		actor.user_id = sessions[id].uid
		index += 1
	for i in range(48):
		# Supplies are placed along open approaches, outside building walls.
		var p := Vector3([-18.0, 18.0, -90.0, 90.0][i % 4], 0.1, -88 + (i / 4) * 16)
		loot[i] = {"p": p, "kind": i % 4}
	world.show_loot(loot)
	phase = "lobby"
	phase_time = 18
	if online:
		for id in sessions:
			if peer_ready(id):
				new_round.rpc_id(id, match_id)

func spawn_position(index: int) -> Vector3:
	var angle := float(index) * 2.39996
	return Vector3(sin(angle) * 90, 1, cos(angle) * 90)

func spawn_actor(id: int, nickname: String, bot: bool, at: Vector3):
	var actor = Actor.new()
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	actor.actor_id = id
	actor.display_name = nickname
	actor.is_bot = bot
	if bot and (not online or dedicated):
		actor.navigator = BotNavigator.new()
	actor.position = at
	actor.target_position = at
	actor.name = "Operator_" + str(id).replace("-", "b")
	add_child(actor)
	actors[id] = actor
	if not dedicated and id == local_id:
		actor.set_local()
	return actor

func begin_round() -> void:
	var human_count := actors.size()
	for i in range(MAX_PLAYERS - human_count):
		spawn_actor(-i - 1, "RANGER-%02d" % (i + 1), true, spawn_position(human_count + i))
	for id in actors:
		var actor = actors[id]
		if not actor.is_bot:
			participants[id] = {"user_id": actor.user_id, "kills": 0, "rank": 0}
	phase = "live"
	elapsed = 0
	phase_time = ROUND_SECONDS
	add_event("Operation live. Last operator standing wins.")

@rpc("authority", "call_remote", "reliable")
func new_round(id: String) -> void:
	network_round_id = id
	clear_actors()
	ui.result_label.text = ""
	ui.show_game()

func _unhandled_input(event: InputEvent) -> void:
	if dedicated or not running:
		return
	if event.is_action_pressed("pause"):
		if ui.inventory.visible:
			ui.set_inventory(false)
			get_viewport().set_input_as_handled()
			return
		ui.set_pause(not ui.pause_panel.visible)
		return
	if not actors.has(local_id):
		return
	var actor = actors[local_id]
	if event.is_action_pressed("inventory") and not event.is_echo() and actor.alive and phase == "live" and not ui.pause_panel.visible:
		ui.set_inventory(not ui.inventory.visible)
		get_viewport().set_input_as_handled()
		return
	if ui.inventory.visible:
		return
	if not actor.alive:
		if not ui.pause_panel.visible:
			if event.is_action_pressed("spectate_next"):
				spectator.cycle(actors, 1)
			elif event.is_action_pressed("spectate_previous"):
				spectator.cycle(actors, -1)
			elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				spectator.orbit(event.relative, ui.sensitivity)
			elif event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					spectator.zoom(-0.5)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					spectator.zoom(0.5)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var scale_aim := 0.55 if Input.is_action_pressed("aim") else 1.0
		actor.yaw = wrapf(actor.yaw - event.relative.x * ui.sensitivity * scale_aim, -PI, PI)
		actor.pitch = clampf(actor.pitch - event.relative.y * ui.sensitivity * scale_aim, -1.45, 1.45)

func change_pause(enabled: bool) -> void:
	get_tree().paused = enabled and running and not online and not dedicated
	ui.pause_feedback(get_tree().paused)
	ui.pause_description.text = "Operation paused. Resume when ready." if not online else "Online operation continues. You remain vulnerable."
	action_latch.clear()

func inventory_action(action: String, index := -1, supply_id := -1) -> void:
	if dedicated or not running or phase != "live" or not ui.inventory.visible or ui.pause_panel.visible or not actors.has(local_id):
		return
	var actor = actors[local_id]
	if not actor.alive:
		return
	var cmd := local_command(actor)
	if action == "weapon" and index >= 0 and index < 3:
		cmd.weapon = index
	elif action in ["reload", "heal", "loot"]:
		cmd[action] = true
	else:
		return
	if online:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			action_command.rpc_id(1, network_round_id, cmd, supply_id)
	else:
		receive_actions(actor, match_id, cmd, supply_id)

func inventory_pickup(id: int) -> void:
	inventory_action("loot", -1, id)

func inventory_equipment(action: String, index: int) -> void:
	inventory_action(action, index)

func inventory_drop(kind: int, count: int) -> void:
	if dedicated or not running or phase != "live" or not ui.inventory.visible or ui.pause_panel.visible or not actors.has(local_id):
		return
	sequence += 1
	if online:
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			drop_command.rpc_id(1, network_round_id, sequence, kind, count)
	else:
		receive_drop(actors[local_id], match_id, sequence, kind, count)

@rpc("any_peer", "call_remote", "reliable", 4)
func drop_command(round_id: String, seq, kind, count) -> void:
	if not dedicated:
		return
	var id := multiplayer.get_remote_sender_id()
	if sessions.has(id) and actors.has(id):
		receive_drop(actors[id], round_id, seq, kind, count)

func receive_drop(actor, round_id: String, seq, kind, count) -> bool:
	if not seq is int or not kind is int or not count is int:
		return false
	if round_id != match_id or phase != "live" or not actor.alive:
		return false
	if seq < 0 or seq > 2147483647 or seq <= actor.last_action_sequence:
		return false
	actor.last_action_sequence = seq
	if seq < actor.last_sequence - 120 or actor.action_tokens < 1:
		return false
	actor.action_tokens -= 1
	if kind not in [0, 1, 3] or count <= 0 or count > 300:
		return false
	# Healing consumes its medkit at completion; keep it reserved until then.
	if kind == 1 and actor.heal_left > 0:
		return false
	var field: String = SupplyRules.FIELDS[kind]
	var stock: int = actor.get(field)
	if count > stock:
		return false
	var target := -1
	for id in loot:
		var item: Dictionary = loot[id]
		if item.has("drop_slot") and item.kind == kind and actor.position.distance_to(item.p) < 0.25 and supply_accessible(actor, item):
			target = id
			break
	if target >= 0:
		loot[target].amount = SupplyRules.amount(loot[target]) + count
	else:
		while loot.has(next_loot_id):
			next_loot_id += 1
		loot[next_loot_id] = {"p": actor.position, "kind": kind, "amount": float(count), "drop_slot": kind}
		next_loot_id += 1
	actor.set(field, stock - count)
	return true

func _physics_process(dt: float) -> void:
	if not running or get_tree().paused:
		return
	if not dedicated and actors.has(local_id):
		var actor = actors[local_id]
		var cmd := local_command(actor)
		if online:
			actor.predict_movement(cmd, dt, phase == "live")
			net_tick += dt
			if net_tick >= 1.0 / 30:
				net_tick = 0
				if phase == "live" and has_actions(cmd):
					var supply_id := int(supply_target(actor).get("id", -1)) if cmd.loot else -1
					action_command.rpc_id(1, network_round_id, cmd, supply_id)
				input_command.rpc_id(1, without_actions(cmd))
				action_latch.clear()
		else:
			apply_command(actor, cmd)
	if online and not dedicated:
		if bot_client:
			bot_test_timer += dt
			if not round_client and bot_test_timer > 20 and not test_menu_started:
				test_menu_started = true
				test_menu_time = phase_time
				ui.set_pause(true)
			if test_menu_started and not test_menu_done and bot_test_timer > 20.6:
				assert(not get_tree().paused and phase_time < test_menu_time - 0.2, "Online menu must continue receiving the advancing round")
				ui.set_pause(false)
				test_menu_done = true
			for grenade in grenades.values():
				if grenade.owner_id == local_id:
					test_grenade_seen = true
			if actors.has(local_id):
				var player = actors[local_id]
				if test_start_position == Vector3.ZERO:
					test_start_position = player.position
				test_moved = test_moved or player.position.distance_to(test_start_position) > 1.0
				test_fired = test_fired or player.ammo < 30
				test_magazines = test_magazines or (test_switch_stage == 3 and player.weapon == 0 and player.reserve == 120 and player.magazines[0] < 30 and player.magazines[1] < 8 and player.magazines[2] < 5)
				test_crouched = test_crouched or (player.crouched and player.head.position.y < 1.1)
				test_recoil = test_recoil or player.recoil > 0
				for other in actors.values():
					if other.actor_id > 0 and other.actor_id != local_id and other.third_person_gun != null:
						if other.third_person_gun.scene_file_path == other.WEAPON_MODELS[other.weapon]:
							test_remote_weapons[other.weapon] = true
					if other.actor_id > 0 and other.actor_id != local_id and other.crouched:
						test_remote_crouch = true
						if other.character_animation.available and other.character_animation.active_clip.begins_with("Crouch"):
							test_remote_animation = true
			if round_client and phase == "finished" and actors.has(local_id) and actors[local_id].rank > 0:
				spectator.update_view(actors, local_id, phase)
				if not actors[local_id].alive:
					assert(spectator.active and spectator.camera.current, "Network death enters spectator camera")
				print("FULL_ROUND_CLIENT_PASS rank=%d spectator=%s" % [actors[local_id].rank, "ok" if spectator.active else "survived"])
				request_quit()
			if not round_client and bot_test_timer > 26:
				var audio_ok: bool = not audio_test or (sound.played_events.get("gun_ar", 0) > 0 and sound.played_events.get("step_hard", 0) + sound.played_events.get("step_grass", 0) > 0)
				if actors.has(local_id) and phase == "live" and actors.size() >= 2 and test_moved and test_fired and test_crouched and test_recoil and test_remote_crouch and test_remote_animation and test_menu_done and test_magazines and test_remote_weapons.size() == 3 and test_grenade_seen and test_grenade_exploded and actors[local_id].grenades == 1 and actors[local_id].prediction_corrections > 20 and audio_ok:
					print("ONLINE_CLIENT_PASS id=%d actors=%d phase=%s stance=ok recoil=ok remote_stance=ok remote_animation=ok grenade=ok explosion=ok action_once=ok weapon_models=ok online_menu=ok magazines=ok reconciliation=ok audio=%s" % [local_id, actors.size(), phase, "ok" if audio_test else "muted"])
					request_quit()
				else:
					push_error("Online smoke test failed to reach active match")
					request_quit(1)
		return
	for id in pending.keys():
		if Time.get_ticks_msec() - pending[id].at > 8000:
			multiplayer.multiplayer_peer.disconnect_peer(id)
	if dedicated:
		var now := Time.get_ticks_msec()
		if not room_id.is_empty() and not room_heartbeat_busy and (now >= room_heartbeat_due or (room_heartbeat_success >= room_heartbeat_attempt and room_signature() != room_heartbeat_signature and now - room_heartbeat_attempt >= 250)):
			report_room()
		retry_time -= dt
		if retry_time <= 0 and not submitting and not result_outbox.is_empty():
			submit_result()
	if phase == "waiting":
		if not sessions.is_empty():
			reset_round()
	elif phase == "lobby":
		phase_time -= dt
		if phase_time <= 0:
			if dedicated and sessions.is_empty():
				release_empty_room()
			else:
				begin_round()
	elif phase == "live":
		elapsed += dt
		phase_time = maxf(0, ROUND_SECONDS - elapsed)
		# Calm first 35 seconds; continuously closes to 4m by the final minute.
		zone = lerpf(110, 4, clampf((elapsed - 35) / 220, 0, 1))
		world.set_zone(zone)
		zone_tick += dt
		for actor in actors.values():
			if actor.is_bot:
				bot_input(actor, dt)
			if dedicated and not actor.is_bot and Time.get_ticks_msec() - actor.last_command_msec > 350:
				actor.move_input = Vector2.ZERO
				actor.shooting = false
			actor.simulate(dt)
		# Capture all actors at the same simulation boundary before resolving fire.
		hit_history.record(elapsed, actors)
		for actor in actors.values():
			if actor.shooting:
				shoot(actor)
		if zone_tick >= 1:
			zone_tick = 0
			for actor in actors.values():
				if Vector2(actor.position.x, actor.position.z).length() > zone:
					damage(actor, 5 + elapsed / 24, 0)
		advance_grenades(dt)
		if alive_count() <= 1 or elapsed >= ROUND_SECONDS:
			finish_round()
	elif phase == "finished":
		phase_time -= dt
		if phase_time <= 0 and dedicated:
			if sessions.is_empty():
				clear_actors()
				phase = "waiting"
				match_id = uuid4()
			else:
				reset_round()
	if dedicated:
		net_tick += dt
		if net_tick >= 0.05:
			net_tick = 0
			broadcast_snapshot()
	if smoke:
		smoke_frames += 1
		if smoke_frames == 15:
			run_smoke_checks()

func local_command(actor) -> Dictionary:
	sequence += 1
	var cmd := {"seq": sequence, "x": 0.0, "z": 0.0, "yaw": actor.yaw, "pitch": actor.pitch, "fire": false, "sprint": false, "crouch": false, "ads": false, "jump": false, "reload": false, "heal": false, "loot": false, "throw": false, "weapon": -1}
	if ui.pause_panel.visible or ui.inventory.visible or not actor.alive:
		action_latch.clear()
		return cmd
	var movement := Input.get_vector("left", "right", "forward", "back")
	cmd.x = movement.x
	cmd.z = movement.y
	cmd.ads = Input.is_action_pressed("aim")
	for action in ["fire", "sprint", "crouch"]:
		cmd[action] = Input.is_action_pressed(action)
	if inventory_pointer_guard:
		inventory_pointer_guard = Input.is_action_pressed("fire") or Input.is_action_pressed("aim")
		cmd.fire = false
		cmd.ads = false
	for action in ["jump", "reload", "heal", "loot", "throw"]:
		cmd[action] = Input.is_action_just_pressed(action)
	for i in range(3):
		if Input.is_action_just_pressed("weapon" + str(i + 1)):
			cmd.weapon = i
	if online:
		for action in ["jump", "reload", "heal", "loot", "throw"]:
			if cmd[action]:
				action_latch[action] = true
			cmd[action] = action_latch.get(action, false)
		if cmd.weapon >= 0:
			action_latch.weapon = cmd.weapon
		cmd.weapon = action_latch.get("weapon", -1)
	if bot_client:
		cmd.z = -1.0 if int(bot_test_timer) % 4 < 2 else 1.0
		cmd.fire = true
		cmd.crouch = int(bot_test_timer) % 6 < 3
		cmd.ads = true
		if phase == "live" and bot_test_timer > 19 and not test_throw_sent:
			cmd.throw = true
			action_latch["throw"] = true
			test_throw_sent = true
		if phase == "live" and ((bot_test_timer > 21 and test_switch_stage == 0) or (bot_test_timer > 23 and test_switch_stage == 1) or (bot_test_timer > 25 and test_switch_stage == 2)):
			test_switch_stage += 1
			cmd.weapon = test_switch_stage % 3
			action_latch.weapon = cmd.weapon
	return cmd

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func input_command(cmd: Dictionary) -> void:
	if not dedicated:
		return
	var id := multiplayer.get_remote_sender_id()
	if not sessions.has(id) or not actors.has(id):
		return
	var actor = actors[id]
	if actor.command_tokens < 1:
		return
	actor.command_tokens -= 1
	if not valid_command(cmd) or int(cmd.seq) <= actor.last_sequence:
		return
	actor.last_command_msec = Time.get_ticks_msec()
	actor.last_sequence = int(cmd.seq)
	apply_command(actor, without_actions(cmd))

func has_actions(cmd: Dictionary) -> bool:
	return cmd.jump or cmd.reload or cmd.heal or cmd.loot or cmd.throw or cmd.weapon >= 0

func without_actions(cmd: Dictionary) -> Dictionary:
	var movement := cmd.duplicate()
	for action in ["jump", "reload", "heal", "loot", "throw"]:
		movement[action] = false
	movement.weapon = -1
	return movement

@rpc("any_peer", "call_remote", "reliable", 4)
func action_command(round_id: String, cmd: Dictionary, loot_target = -1) -> void:
	if not dedicated:
		return
	var id := multiplayer.get_remote_sender_id()
	if not sessions.has(id) or not actors.has(id):
		return
	receive_actions(actors[id], round_id, cmd, loot_target)

func receive_actions(actor, round_id: String, cmd: Dictionary, loot_target = -1) -> bool:
	if not loot_target is int or loot_target < -1 or loot_target > 4294967295:
		return false
	if round_id != match_id or phase != "live" or not actor.alive or not valid_command(cmd):
		return false
	if cmd.seq != floorf(cmd.seq) or cmd.seq < 0 or cmd.seq > 2147483647 or cmd.seq <= actor.last_action_sequence:
		return false
	actor.last_action_sequence = int(cmd.seq)
	# Drop delayed backlog once newer movement has advanced over two seconds.
	if cmd.seq < actor.last_sequence - 120 or not has_actions(cmd) or actor.action_tokens < 1:
		return false
	actor.action_tokens -= 1
	# A reliable action may arrive before/after the movement packet carrying its
	# view. Use the event's aim for throwing without changing held movement.
	var saved_yaw: float = actor.yaw
	var saved_pitch: float = actor.pitch
	actor.yaw = cmd.yaw
	actor.pitch = cmd.pitch
	apply_actions(actor, cmd, loot_target, true)
	actor.yaw = saved_yaw
	actor.pitch = saved_pitch
	return true

func valid_command(cmd: Dictionary) -> bool:
	if cmd.size() != 15:
		return false
	for key in ["seq", "x", "z", "yaw", "pitch", "weapon"]:
		if not cmd.has(key) or not (cmd[key] is float or cmd[key] is int):
			return false
		if not is_finite(float(cmd[key])):
			return false
	for key in ["fire", "sprint", "crouch", "ads", "jump", "reload", "heal", "loot", "throw"]:
		if not cmd.has(key) or not cmd[key] is bool:
			return false
	return absf(cmd.x) <= 1 and absf(cmd.z) <= 1 and absf(cmd.yaw) <= PI + 0.01 and absf(cmd.pitch) <= 1.46 and cmd.weapon >= -1 and cmd.weapon <= 2

func apply_command(actor, cmd: Dictionary) -> void:
	actor.move_input = Vector2(cmd.x, cmd.z).limit_length()
	actor.yaw = cmd.yaw
	actor.pitch = cmd.pitch
	actor.shooting = cmd.fire and phase == "live"
	actor.sprint = cmd.sprint
	actor.crouch = cmd.crouch
	actor.aiming = cmd.ads
	apply_actions(actor, cmd)

func apply_actions(actor, cmd: Dictionary, loot_target := -1, explicit_pickup := false) -> void:
	if phase != "live" or not actor.alive:
		return
	actor.jump_requested = actor.jump_requested or cmd.jump
	if cmd.reload:
		actor.reload_weapon()
	if cmd.heal:
		actor.heal()
	if cmd.weapon >= 0:
		actor.switch_weapon(int(cmd.weapon))
	if cmd.loot and (not explicit_pickup or loot_target >= 0):
		pickup(actor, loot_target)
	if cmd.throw:
		throw_grenade(actor)

func bot_input(actor, dt: float) -> void:
	if not actor.alive:
		return
	actor.bot_think -= dt
	actor.bot_patrol_left -= dt
	actor.bot_memory_left = maxf(0, actor.bot_memory_left - dt)
	if actor.bot_think <= 0:
		actor.bot_think = rng.randf_range(0.3, 0.65)
		var best := 70.0
		actor.target_id = 0
		for other in actors.values():
			if other == actor or not other.alive:
				continue
			var distance: float = actor.position.distance_to(other.position)
			if distance < best and visible_target(actor, other):
				best = distance
				actor.target_id = other.actor_id
	actor.shooting = false
	var destination: Vector3 = actor.bot_destination
	if actors.has(actor.target_id) and actors[actor.target_id].alive:
		var target = actors[actor.target_id]
		var aim: Vector3 = target.aim_position() - actor.eye_position()
		actor.yaw = atan2(-aim.x, -aim.z)
		actor.pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
		actor.shooting = visible_target(actor, target)
		if actor.shooting:
			actor.bot_last_seen = target.position
			actor.bot_memory_left = 3.0
		destination = actor.bot_last_seen
		if actor.shooting and aim.length() < 24:
			var outward: Vector3 = actor.position - target.position
			outward.y = 0
			outward = outward.normalized()
			if aim.length() < 12:
				destination = actor.position + outward * 8
			else:
				var side := 1.0 if sin(elapsed * 0.35 + actor.actor_id) > 0 else -1.0
				destination = actor.position + Vector3(-outward.z, 0, outward.x) * side * 5
	elif actor.bot_memory_left > 0:
		destination = actor.bot_last_seen
	else:
		if actor.bot_patrol_left <= 0 or actor.navigator.finished:
			actor.bot_patrol_left = rng.randf_range(4, 8)
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf()) * maxf(4, zone - 12)
			actor.bot_destination = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
			var nearest := 35.0
			for supply in loot.values():
				if Vector2(supply.p.x, supply.p.z).length() > maxf(4, zone - 7):
					continue
				var wanted: bool = (supply.kind == 0 and actor.reserve < 45) or (supply.kind == 1 and actor.medkits == 0) or (supply.kind == 2 and actor.armor < 25)
				var distance: float = actor.position.distance_to(supply.p)
				if wanted and distance < nearest:
					nearest = distance
					actor.bot_destination = supply.p
		destination = actor.bot_destination
	var radial := Vector2(actor.position.x, actor.position.z)
	actor.sprint = radial.length() > maxf(4, zone - 7)
	if actor.sprint:
		var safe := radial.normalized() * maxf(0, zone - 14)
		destination = Vector3(safe.x, 0, safe.y)
	var direction: Vector3 = actor.navigator.steer(actor, world, destination, dt)
	# Short-range separation supplements global paths around static geometry.
	if direction.length_squared() > 0:
		for other in actors.values():
			if other == actor or not other.alive:
				continue
			var away: Vector3 = actor.position - other.position
			away.y = 0
			var gap := away.length()
			if gap > 0.01 and gap < 1.2:
				direction += away / gap * (1.2 - gap)
		direction = direction.normalized()
	if not actor.shooting:
		if direction.length_squared() > 0:
			actor.yaw = atan2(-direction.x, -direction.z)
		actor.pitch = 0
	var local_direction: Vector3 = Basis(Vector3.UP, -actor.yaw) * direction
	actor.move_input = Vector2(local_direction.x, local_direction.z).limit_length()

	if elapsed > 8 and actors.has(actor.target_id) and actor.grenades > 0:
		var distance: float = actor.position.distance_to(actors[actor.target_id].position)
		if distance > 23 and distance < 32 and actor.shooting and actor.throw_left <= 0:
			var saved_pitch: float = actor.pitch
			actor.pitch = 0.25
			throw_grenade(actor)
			actor.pitch = saved_pitch
	if actor.ammo == 0:
		actor.reload_weapon()
	if actor.health < 40 and actor.target_id == 0:
		actor.heal()
	pickup(actor)

func visible_target(actor, other) -> bool:
	var query := PhysicsRayQueryParameters3D.create(actor.eye_position(), other.aim_position(), 3, [actor.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == other

func shot_rewind_age(actor) -> float:
	if not dedicated or actor.is_bot or not peer_ready(actor.actor_id):
		return 0
	var peer: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(actor.actor_id)
	return HitHistory.rewind_age(peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))

func trace_shot(actor, origin: Vector3, direction: Vector3, rewind: float) -> Dictionary:
	rewind = clampf(rewind, 0, HitHistory.MAX_REWIND) if is_finite(rewind) else 0
	if rewind <= 0 or hit_history.poses_at(elapsed - rewind).is_empty():
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180, 3, [actor.get_rid()])
		return get_world_3d().direct_space_state.intersect_ray(query)
	# Static world cover is never rewound. Historical capsules are queried
	# analytically, so no live physics body is moved or exposed to other systems.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 180, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	var limit: float = 180 if wall.is_empty() else origin.distance_to(wall.position)
	var hit: Dictionary = hit_history.trace(elapsed - rewind, origin, direction, limit, actor.actor_id, actors)
	return wall if hit.is_empty() else hit

func shoot(actor) -> void:
	if not actor.alive or actor.fire_left > 0 or actor.reload_left > 0 or actor.heal_left > 0 or actor.ammo <= 0 or actor.throw_left > 0 or phase != "live":
		return
	actor.weapon_blocked = actor.weapon_obstructed(actor.aiming)
	if actor.weapon_blocked:
		return
	actor.ammo -= 1
	actor.fire_left = actor.INTERVAL[actor.weapon]
	if actor.is_bot:
		actor.fire_left *= 3.0
	var origin: Vector3 = actor.eye_position()
	var last_end := origin
	var rewind := shot_rewind_age(actor)
	if dedicated and rewind > 0 and not rewind_peers.has(actor.actor_id) and not hit_history.poses_at(elapsed - rewind).is_empty():
		rewind_peers[actor.actor_id] = true
		print("REWIND_ACTIVE peer=%d age_ms=%d" % [actor.actor_id, int(rewind * 1000)])
	for pellet in range(7 if actor.weapon == 1 else 1):
		var spread: float = actor.shot_spread()
		if actor.is_bot:
			spread += 0.07
		var direction := Basis(Vector3.UP, actor.yaw) * Basis(Vector3.RIGHT, clampf(actor.pitch + actor.recoil, -1.5, 1.5)) * Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread), -1).normalized()
		var hit := trace_shot(actor, origin, direction, rewind)
		last_end = origin + direction * 100 if hit.is_empty() else hit.position
		if not hit.is_empty() and hit.collider is CharacterBody3D:
			var target = hit.collider
			var headshot: bool = hit.get("headshot", hit.position.y - target.position.y > target.headshot_height())
			var amount: float = actor.DAMAGE[actor.weapon] * (1.65 if headshot else 1.0)
			if actor.weapon == 1:
				amount *= clampf(1 - origin.distance_to(hit.position) / 60, 0.15, 1)
			damage(target, amount, actor.actor_id, false, headshot)
	actor.add_recoil()
	if online:
		for id in sessions:
			if peer_ready(id):
				shot_fx.rpc_id(id, actor.actor_id, origin, last_end, actor.weapon)
	else:
		shot_fx(actor.actor_id, origin, last_end, actor.weapon)

@rpc("authority", "call_remote", "unreliable", 2)
func shot_fx(id: int, origin: Vector3, end: Vector3, kind: int) -> void:
	if dedicated:
		return
	if actors.has(id):
		actors[id].flash_left = 0.05
		actors[id].weapon_kick = 1.0
	sound.shot(origin, kind)
	var line := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("ffe3a0")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, m)
	var visual_origin := origin
	if id == local_id and actors.has(id):
		visual_origin = actors[id].muzzle.global_position
	mesh.surface_add_vertex(visual_origin)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	line.mesh = mesh
	add_child(line)
	get_tree().create_timer(0.065, false).timeout.connect(line.queue_free)

func damage(target, amount: float, attacker_id: int, bypass_protection := false, headshot := false, cause := "THE ZONE", impact_origin = null) -> void:
	if phase == "finished" or not target.alive or (not bypass_protection and phase == "live" and elapsed < 5):
		return
	var before: float = target.health + target.armor
	target.apply_damage(amount)
	var actual_damage: float = before - target.health - target.armor
	if actors.has(attacker_id) and attacker_id != target.actor_id:
		deliver_feedback(attacker_id, 0, actual_damage, headshot, not target.alive, target.position)
	var source_position: Vector3 = actors[attacker_id].position if actors.has(attacker_id) else target.position
	if impact_origin is Vector3:
		source_position = impact_origin
	deliver_feedback(target.actor_id, 1, actual_damage, false, not target.alive, source_position)
	if not target.alive:
		target.rank = alive_count() + 1
		if target.rank == 1:
			last_eliminated_name = target.display_name
		if participants.has(target.actor_id):
			participants[target.actor_id].rank = target.rank
		var source: String = cause
		if actors.has(attacker_id) and attacker_id != target.actor_id:
			var attacker = actors[attacker_id]
			attacker.kills += 1
			source = attacker.display_name
			if participants.has(attacker_id):
				participants[attacker_id].kills = attacker.kills
		elif participants.has(attacker_id) and attacker_id != target.actor_id:
			participants[attacker_id].kills += 1
			source = "DISCONNECTED OPERATOR"
		add_event(source + "  >  " + target.display_name)
		drop_inventory(target)

func drop_inventory(actor) -> void:
	if actor.alive or (online and not dedicated):
		return
	var amounts := [actor.total_ammunition(), actor.medkits, actor.armor, actor.grenades]
	for kind in range(amounts.size()):
		if amounts[kind] <= 0:
			continue
		while loot.has(next_loot_id):
			next_loot_id += 1
		loot[next_loot_id] = {"p": actor.position, "kind": kind, "amount": float(amounts[kind]), "drop_slot": kind}
		next_loot_id += 1
	actor.magazines = PackedInt32Array([0, 0, 0])
	actor.reserve = 0
	actor.medkits = 0
	actor.armor = 0
	actor.grenades = 0

func supply_accessible(actor, item: Dictionary) -> bool:
	if actor.position.distance_to(item.p) >= SupplyRules.RANGE:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.eye_position(), item.p + Vector3.UP * 0.35, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func supply_target(actor) -> Dictionary:
	if not actor.alive or phase != "live":
		return {}
	var best := {}
	var best_distance := INF
	var best_usable := false
	for id in loot:
		var item: Dictionary = loot[id]
		var distance: float = actor.position.distance_to(item.p)
		var usable := SupplyRules.capacity(actor, int(item.kind)) > 0
		if (best_usable and not usable) or (usable == best_usable and distance >= best_distance):
			continue
		if not supply_accessible(actor, item):
			continue
		best = {"id": id, "kind": item.kind, "amount": SupplyRules.amount(item), "usable": usable}
		best_distance = distance
		best_usable = usable
	return best

func pickup(actor, requested_id := -1) -> bool:
	if not actor.alive or phase != "live":
		return false
	var id := requested_id
	if id < 0:
		id = int(supply_target(actor).get("id", -1))
	if not loot.has(id) or not supply_accessible(actor, loot[id]):
		return false
	if SupplyRules.transfer(actor, loot[id]) <= 0:
		return false
	if SupplyRules.amount(loot[id]) <= 0.00001:
		loot.erase(id)
	return true

func alive_count() -> int:
	var count := 0
	for actor in actors.values():
		if actor.alive:
			count += 1
	return count

func finish_round() -> void:
	if phase == "finished":
		return
	# Time limit ties are resolved by health, then kills, then stable actor id.
	var survivors: Array = actors.values().filter(func(a): return a.alive)
	survivors.sort_custom(func(a, b): return a.health > b.health if a.health != b.health else (a.kills > b.kills if a.kills != b.kills else a.actor_id < b.actor_id))
	for i in range(survivors.size()):
		var actor = survivors[i]
		actor.rank = i + 1
		if participants.has(actor.actor_id):
			participants[actor.actor_id].rank = actor.rank
	clear_grenades()
	phase = "finished"
	phase_time = 12
	# Damage resolves in simulation order. The last eliminated operator retains
	# rank 1 even if another effect kills them before this tick completes.
	var winner: String = survivors[0].display_name if not survivors.is_empty() else (last_eliminated_name if last_eliminated_name != "" else "No winner")
	add_event("Operation complete / " + winner)
	if dedicated:
		var players: Array = []
		for entry in participants.values():
			if entry.user_id != "" and entry.rank > 0:
				players.append(entry)
		if not players.is_empty():
			result_outbox.append({"match_id": match_id, "players": players})
			save_outbox()
	elif not online:
		save_local_operation()

func save_local_operation() -> void:
	if local_profile == null or online or phase not in ["live", "finished"] or not actors.has(local_id) or match_id == local_recorded_id:
		return
	var actor = actors[local_id]
	var completed: bool = phase == "finished" or not actor.alive
	var record := {"id": match_id, "finished_at": int(Time.get_unix_time_from_system()), "status": "completed" if completed else "abandoned", "rank": actor.rank if completed else 0, "kills": actor.kills, "seconds": int(clampf(elapsed, 0, ROUND_SECONDS)), "map": "ash_valley"}
	local_outbox.append(record)
	local_recorded_id = match_id
	flush_local_results()

func flush_local_results() -> void:
	if local_profile == null:
		return
	for record in local_outbox.duplicate():
		if local_profile.store(record):
			local_outbox.erase(record)

func show_local_history() -> void:
	if local_profile == null or ui == null:
		return
	flush_local_results()
	var summary: Dictionary = local_profile.summary()
	summary["pending"] = local_outbox.size()
	summary["save_error"] = local_profile.last_error if not local_outbox.is_empty() else ""
	ui.show_local_history(summary)
	if local_outbox.is_empty():
		ui.status.text = "Local history loaded."

func add_event(message: String) -> void:
	events.append(message)
	if events.size() > 5:
		events.pop_front()

func _process(dt: float) -> void:
	if dedicated or not running or get_tree().paused:
		return
	for id in actors:
		actors[id].render_frame(dt, online, id == local_id, Input.is_action_pressed("aim"))
	spectator.update_view(actors, local_id, phase)
	sound.update_actors(actors, world, get_viewport().get_camera_3d())
	world.show_loot(loot)
	world.set_zone(zone)
	ui.update_scoreboard(actors.values(), Input.is_action_pressed("scoreboard") and not ui.pause_panel.visible and not ui.inventory.visible)
	if actors.has(local_id):
		var actor = actors[local_id]
		if ui.inventory.visible:
			if not actor.alive or phase != "live":
				ui.set_inventory(false)
			else:
				var supplies: Array = []
				for id in loot:
					if supply_accessible(actor, loot[id]):
						supplies.append({"id": id, "kind": loot[id].kind, "amount": SupplyRules.amount(loot[id]), "distance": actor.position.distance_to(loot[id].p), "usable": SupplyRules.capacity(actor, loot[id].kind) > 0})
				ui.inventory.refresh(actor, supplies)
		var supply := supply_target(actor) if not spectator.active else {}
		world.highlight_supply(int(supply.get("id", -1)))
		ui.supply_prompt = ""
		if not supply.is_empty():
			var item_name: String = SupplyRules.NAMES[int(supply.kind)]
			var quantity: float = supply.amount
			var quantity_text := str(int(quantity)) if is_equal_approx(quantity, roundf(quantity)) else String.num(quantity, 1)
			ui.supply_prompt = ("E  %s ×%s" % [item_name, quantity_text]) if supply.usable else item_name + " / INVENTORY FULL"
		var message := ""
		if phase == "finished":
			message = ("VICTORY" if actor.rank == 1 else "OPERATION COMPLETE") + "\nPLACEMENT  #%d  /  %d ELIMINATIONS" % [actor.rank, actor.kills]
			message += "\nNext operation in %ds" % maxi(0, int(phase_time)) if online else "\nESC  /  RETURN TO DEPLOYMENT"
			if not online and local_profile != null:
				message += "\nLOCAL RESULT SAVED" if local_outbox.is_empty() else "\nLOCAL SAVE PENDING / RETRY IN MENU"
		if phase == "lobby":
			message = "DEPLOYING IN %02d\nWaiting for operators…" % maxi(0, int(phase_time))
		var viewed_actor = actors.get(spectator.target_id, actor) if spectator.active else actor
		ui.sight_aiming = not spectator.active and actor.first_person.aim_blend > 0.5
		ui.grenade_warning_distance = INF
		for grenade in grenades.values():
			ui.grenade_warning_distance = minf(ui.grenade_warning_distance, viewed_actor.position.distance_to(grenade.position))
		ui.update_hud(viewed_actor, alive_count(), phase, phase_time, zone, events, message)
		ui.set_spectator(spectator.active, spectator.target_name, actor.rank)

func peer_connected(id: int) -> void:
	if dedicated:
		var peer: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(id)
		peer.set_timeout(32, 5000, 10000)
		pending[id] = {"at": Time.get_ticks_msec(), "checking": false}

@rpc("any_peer", "call_remote", "reliable", 4)
func leave_operation() -> void:
	if dedicated:
		var id := multiplayer.get_remote_sender_id()
		if (sessions.has(id) or pending.has(id)) and peer_ready(id):
			multiplayer.multiplayer_peer.disconnect_peer(id)

func peer_disconnected(id: int) -> void:
	if dedicated:
		print("PEER_DISCONNECTED peer=" + str(id))
	pending.erase(id)
	sessions.erase(id)
	if dedicated and actors.has(id):
		if phase == "live":
			damage(actors[id], 10000, 0, true)
		remove_child(actors[id])
		actors[id].queue_free()
		actors.erase(id)
		if sessions.is_empty() and phase in ["live", "finished"]:
			release_empty_room()

func release_empty_room() -> void:
	if not dedicated or not sessions.is_empty():
		return
	if phase == "live":
		finish_round()
	clear_actors()
	phase = "waiting"
	match_id = uuid4()
	print("ROOM_IDLE room=" + room_id)

func connected() -> void:
	if not online or shutdown_requested or admission_ticket.is_empty():
		return
	local_id = multiplayer.get_unique_id()
	authenticate.rpc_id(1, ticket)
	ticket = ""

@rpc("any_peer", "call_remote", "reliable")
func authenticate(value: String) -> void:
	if not dedicated:
		return
	var id := multiplayer.get_remote_sender_id()
	if not pending.has(id) or pending[id].checking or value.length() > 128 or value.length() < 20:
		return
	if phase not in ["waiting", "lobby"] or Time.get_ticks_msec() - room_heartbeat_success > 10000:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	pending[id].checking = true
	var admission_generation := match_id
	var payload := ticket_payload(value)
	payload.merge({"room_id": room_id, "instance_id": room_instance, "generation": admission_generation})
	var response: Dictionary = await http_call("/internal/rooms/tickets/consume", payload, true)
	if not pending.has(id):
		return
	if not peer_ready(id):
		pending.erase(id)
		return
	if response.code != 200 or sessions.size() >= MAX_PLAYERS or match_id != admission_generation or phase not in ["waiting", "lobby"]:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	for session in sessions.values():
		if session.uid == response.body.uid:
			multiplayer.multiplayer_peer.disconnect_peer(id)
			return
	sessions[id] = response.body
	pending.erase(id)
	last_loot_hash = -1
	if phase == "waiting":
		reset_round()
	else:
		var actor = spawn_actor(id, response.body.username, false, spawn_position(sessions.size() - 1))
		actor.user_id = response.body.uid
		if phase == "live" or phase == "finished":
			actor.apply_damage(10000)
	accepted.rpc_id(id, match_id)
	print("AUTHENTICATED peer=" + str(id))

@rpc("authority", "call_remote", "reliable")
func accepted(id: String) -> void:
	if not online or shutdown_requested:
		return
	admission_ticket = ""
	admission_token = ""
	network_round_id = id
	running = true
	authenticated_at = Time.get_ticks_msec()
	ui.show_game()

func broadcast_snapshot() -> void:
	var states: Array = []
	for actor in actors.values():
		states.append(actor.pack())
	var supplies_changed := loot.hash() != last_loot_hash
	last_loot_hash = loot.hash()
	var grenade_states: Array = []
	for grenade in grenades.values():
		grenade_states.append(grenade.pack())
	for id in sessions:
		if not peer_ready(id):
			continue
		for offset in range(0, maxi(1, grenade_states.size()), 6):
			var data := {"round": match_id, "states": grenade_states.slice(offset, offset + 6), "ids": grenades.keys()}
			grenade_snapshot.rpc_id(id, var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE))
		if supplies_changed:
			world_sync.rpc_id(id, match_id, loot)
		# Four actors per compressed packet stay below the ENet MTU.
		for offset in range(0, states.size(), 4):
			var payload := {"round_id": match_id, "actors": states.slice(offset, offset + 4), "roster": actors.keys(), "phase": phase, "time": phase_time, "zone": zone, "events": events}
			var packet := var_to_bytes(payload).compress(FileAccess.COMPRESSION_DEFLATE)
			if packet.size() > 1150:
				push_warning("Snapshot exceeds target packet size: " + str(packet.size()))
			snapshot.rpc_id(id, packet)

@rpc("authority", "call_remote", "reliable")
func world_sync(id: String, supplies: Dictionary) -> void:
	if not dedicated and (network_round_id == "" or network_round_id == id):
		loot = supplies

@rpc("authority", "call_remote", "unreliable_ordered", 3)
func snapshot(packet: PackedByteArray) -> void:
	if dedicated:
		return
	var payload: Dictionary = bytes_to_var(packet.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE))
	if network_round_id != "" and payload.round_id != network_round_id:
		return
	for data in payload.actors:
		if not actors.has(data.id):
			spawn_actor(data.id, data.n, data.b, data.p)
		actors[data.id].unpack(data, data.id == local_id)
	for id in actors.keys():
		if not payload.roster.has(id):
			actors[id].queue_free()
			actors.erase(id)
	phase = payload.phase
	phase_time = payload.time
	zone = payload.zone
	events = payload.events

func sign_in(username: String, password: String, register: bool, endpoint: String) -> void:
	connection_attempt += 1
	var attempt_id := connection_attempt
	ui.busy = true
	ui.connection_cancel.disabled = false
	api_url = endpoint
	var preflight: Dictionary = await http_call("/protocol", {}, false, HTTPClient.METHOD_GET)
	if attempt_id != connection_attempt:
		return
	if preflight.code != 200:
		ui.show_menu("Server update required: build information unavailable." if preflight.code == 404 else "Operations service unavailable. Check the API address and retry.")
		if bot_client:
			request_quit(1)
		return
	if not compatible_build(preflight.body):
		var required_version := "updated client"
		if preflight.body is Dictionary:
			required_version = str(preflight.body.get("client_version", required_version))
		ui.show_menu("Game version mismatch. Required build: " + required_version)
		if bot_client:
			request_quit(1)
		return
	var response: Dictionary = await http_call("/auth/register" if register else "/auth/login", {"username": username, "password": password})
	if attempt_id != connection_attempt:
		return
	if response.code != 200 and response.code != 201:
		ui.show_menu("Account request failed: " + error_message(response))
		if bot_client:
			request_quit(1)
		return
	token = response.body.token
	token_origin = api_url
	var attempt_token: String = token
	var join_payload := build_info.duplicate()
	if bot_client and OS.has_environment("TEST_ROOM_ID"):
		join_payload.room_id = OS.get_environment("TEST_ROOM_ID")
	elif bot_client and OS.has_environment("TEST_GAME_PORT"):
		join_payload.room_id = "room-" + OS.get_environment("TEST_GAME_PORT")
	ui.status.text = "Finding an available operation…"
	for attempt in range(4):
		if attempt_id != connection_attempt:
			return
		response = await http_call("/matchmaking/rooms/join", join_payload)
		if attempt_id != connection_attempt:
			if response.code == 200:
				cancel_ticket(str(response.body.get("ticket", "")), endpoint, attempt_token)
			return
		if response.code == 200:
			break
		if response.code != 503 and not (response.code == 409 and str(response.body.get("detail", "")).begins_with("Already connected")):
			break
		if attempt < 3:
			await get_tree().create_timer(2, true, false, true).timeout
	if response.code != 200:
		ui.show_menu("Matchmaking failed: " + error_message(response))
		if bot_client:
			request_quit(1)
		return
	if not compatible_build(response.body.get("build", {})):
		cancel_ticket(str(response.body.get("ticket", "")), endpoint, attempt_token)
		ui.show_menu("Matchmaking returned an incompatible game build.")
		return
	ticket = response.body.ticket
	admission_ticket = ticket
	admission_origin = endpoint
	admission_token = attempt_token
	room_id = response.body.room_id
	var peer := ENetMultiplayerPeer.new()
	var target_port: int = int(response.body.port)
	if bot_client and OS.has_environment("TEST_GAME_PORT"):
		target_port = int(OS.get_environment("TEST_GAME_PORT"))
	var error := peer.create_client(response.body.host, target_port)
	if error != OK:
		cancel_admission()
		ui.show_menu("Network error: " + str(error))
		return
	online = true
	multiplayer.multiplayer_peer = peer
	ui.status.text = "Authenticating game connection…"
	# A stalled handshake must return control to the user.
	get_tree().create_timer(12).timeout.connect(func():
		if attempt_id == connection_attempt and online and not running:
			leave("Game connection timed out; please retry")
	)

func cancel_ticket(value: String, origin: String, bearer: String) -> void:
	if value.is_empty() or bearer.is_empty():
		return
	var request := HTTPRequest.new()
	request.timeout = 2
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + bearer])
	if request.request(origin + "/matchmaking/rooms/cancel", headers, HTTPClient.METHOD_POST, JSON.stringify({"ticket": value})) == OK:
		await request.request_completed
	request.queue_free()

func cancel_admission() -> void:
	var value := admission_ticket
	var origin := admission_origin
	var bearer := admission_token
	admission_ticket = ""
	admission_token = ""
	ticket = ""
	await cancel_ticket(value, origin, bearer)

func http_call(path: String, body: Dictionary, internal := false, method := HTTPClient.METHOD_POST) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = 7
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if internal:
		headers.append("X-Server-Key: " + server_key)
	elif token != "" and token_origin == api_url:
		headers.append("Authorization: Bearer " + token)
	var error := request.request(api_url + path, headers, method, "" if method == HTTPClient.METHOD_GET else JSON.stringify(body))
	if error != OK:
		request.queue_free()
		return {"code": 0, "body": {"detail": "Cannot start HTTP request"}}
	var response: Array = await request.request_completed
	request.queue_free()
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	return {"code": response[1], "body": parsed if parsed is Dictionary or parsed is Array else {"detail": "Service unavailable"}}

func error_message(response: Dictionary) -> String:
	return str(response.body.get("detail", "Connection failed"))

func leave(message := "") -> void:
	if dedicated or shutdown_requested:
		return
	save_local_operation()
	connection_attempt += 1
	cancel_admission()
	get_tree().paused = false
	running = false
	online = false
	network_round_id = ""
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	clear_actors()
	sessions.clear()
	loot.clear()
	world.show_loot(loot)
	phase = "standby"
	lobby_camera.current = true
	ui.show_menu(message)
	if bot_client:
		push_error(message)
		request_quit(1)

func uuid4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var h := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

func save_outbox() -> void:
	var file := FileAccess.open("user://results.tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result_outbox))
		file.close()
		DirAccess.rename_absolute("user://results.tmp", "user://results.json")

func load_outbox() -> void:
	if FileAccess.file_exists("user://results.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://results.json"))
		if parsed is Array:
			result_outbox = parsed

func submit_result() -> void:
	submitting = true
	var response: Dictionary = await http_call("/internal/results", result_outbox[0], true)
	if response.code == 200:
		result_outbox.pop_front()
		save_outbox()
		print("RESULT_PERSISTED")
	else:
		push_warning("Result delivery pending; HTTP " + str(response.code))
	retry_time = 10
	submitting = false

func run_smoke_checks() -> void:
	var actor = actors[local_id]
	assert(actors.size() == MAX_PLAYERS, "Full offline roster")
	assert(actor.character_animation.available and actor.character_animation.clips.has("CrouchReload"), "Packaged skinned character and animation clips load")
	assert(loot.size() > 20, "Loot exists")
	var health_before: float = actor.health
	actor.apply_damage(20)
	assert(actor.health < health_before and actor.armor < 50, "Armor absorbs damage")
	actor.ammo = 0
	actor.reload_weapon()
	actor.simulate(3)
	assert(actor.ammo == 30 and actor.reserve == 90, "Reload conserves ammunition")
	actor.health = 30
	actor.heal()
	actor.simulate(4)
	assert(actor.health == 95 and actor.medkits == 1, "Healing consumes medkit")
	var rounds: int = actor.total_ammunition()
	actor.switch_weapon(2)
	assert(actor.total_ammunition() == rounds, "Weapon switching conserves ammo")
	var cmd := local_command(actor)
	assert(valid_command(cmd), "Valid client command accepted")
	cmd.x = NAN
	assert(not valid_command(cmd), "Non-finite input rejected")
	elapsed = 10
	running = false
	# Isolate two actors and wait for physics broadphase to register their transforms.
	var victim = actors[-1]
	actor.position = Vector3(0, 1, 20)
	actor.yaw = 0
	actor.pitch = 0
	actor.weapon = 0
	actor.ammo = 30
	actor.fire_left = 0
	victim.position = Vector3(0, 1, 10)
	victim.health = 100
	victim.armor = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	shoot(actor)
	assert(victim.health < 100, "Authoritative ray damages visible target")
	var after_shot: int = actor.ammo
	shoot(actor)
	assert(actor.ammo == after_shot, "Fire interval prevents rapid-fire bypass")
	var wall = world.block(Vector3(0, 2, 15), Vector3(5, 5, 1), "465a61")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var victim_health: float = victim.health
	actor.fire_left = 0
	shoot(actor)
	assert(victim.health == victim_health, "Solid cover blocks bullets")
	wall.queue_free()
	for other in actors.values():
		if other != actor:
			damage(other, 10000, local_id)
	finish_round()
	assert(actor.rank == 1 and actor.kills == 15 and phase == "finished", "Victory and kills resolve")
	await get_tree().create_timer(0.15).timeout
	print("OFFLINE_SMOKE_PASS actors=16 reload=ok heal=ok damage=ok victory=ok raycast=ok cover=ok fire_interval=ok rig=ok")
	request_quit()

func capture_frame() -> void:
	await get_tree().create_timer(2, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := OS.get_environment("CAPTURE_PATH")
	image.save_png(path)
	print("CAPTURE_SAVED " + path)
	request_quit()

func show_leaderboard(endpoint: String) -> void:
	if ui.busy:
		return
	api_url = endpoint
	ui.status.text = "Loading leaderboard…"
	var response: Dictionary = await http_call("/leaderboard", {}, false, HTTPClient.METHOD_GET)
	if response.code != 200 or not response.body is Array:
		ui.status.text = "Leaderboard unavailable; start the services and retry."
		return
	var profile: Dictionary = {}
	if token != "":
		var own: Dictionary = await http_call("/profile", {}, false, HTTPClient.METHOD_GET)
		if own.code == 200:
			profile = own.body
	ui.show_leaderboard(response.body, profile)
	ui.status.text = "Leaderboard loaded."

func deliver_feedback(id: int, kind: int, amount: float, headshot: bool, killed: bool, origin: Vector3) -> void:
	if dedicated:
		if sessions.has(id) and peer_ready(id):
			combat_feedback.rpc_id(id, kind, amount, headshot, killed, origin)
	elif id == local_id:
		combat_feedback(kind, amount, headshot, killed, origin)

@rpc("authority", "call_remote", "reliable")
func combat_feedback(kind: int, amount: float, headshot: bool, killed: bool, origin: Vector3) -> void:
	if not dedicated and ui:
		ui.combat_feedback(kind, amount, headshot, killed, origin)
		sound.feedback(kind, killed)

func peer_ready(id: int) -> bool:
	if not dedicated or not multiplayer.get_peers().has(id):
		return false
	var peer: ENetPacketPeer = multiplayer.multiplayer_peer.get_peer(id)
	return peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED and peer.get_channels() > 0

func clear_grenades() -> void:
	for grenade in grenades.values():
		remove_child(grenade)
		grenade.queue_free()
	grenades.clear()
	grenade_tombstones.clear()

func throw_grenade(actor) -> bool:
	if phase != "live" or not actor.alive or actor.grenades <= 0 or actor.throw_left > 0 or actor.reload_left > 0 or actor.heal_left > 0 or grenades.size() >= 32:
		return false
	var direction := Basis(Vector3.UP, actor.yaw) * Basis(Vector3.RIGHT, actor.pitch) * Vector3.FORWARD
	var origin: Vector3 = actor.eye_position()
	var destination: Vector3 = origin + direction * 0.55
	# Sweep the grenade volume, not just its center, to avoid starting through a wall.
	var shape := SphereShape3D.new()
	shape.radius = 0.13
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = 1
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	query.motion = destination - origin
	var travel := get_world_3d().direct_space_state.cast_motion(query)
	destination = origin + query.motion * maxf(0, travel[0] - 0.02)
	var grenade = Grenade.new()
	grenade.process_mode = Node.PROCESS_MODE_PAUSABLE
	grenade.grenade_id = next_grenade_id
	next_grenade_id += 1
	grenade.owner_id = actor.actor_id
	grenade.position = destination
	add_child(grenade)
	grenade.linear_velocity = direction * 17 + Vector3.UP * 3 + actor.velocity * 0.4
	grenade.angular_velocity = Vector3(5, 3, 4)
	grenades[grenade.grenade_id] = grenade
	actor.grenades -= 1
	actor.throw_left = 0.7
	return true

func advance_grenades(dt: float) -> void:
	for id in grenades.keys():
		var grenade = grenades[id]
		grenade.fuse -= dt
		if grenade.fuse <= 0:
			detonate_grenade(id)

func explosion_exposure(origin: Vector3, actor) -> float:
	var visible := 0.0
	for point in [actor.position + Vector3.UP * 0.25, actor.aim_position(), actor.eye_position()]:
		var ray := PhysicsRayQueryParameters3D.create(origin, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			visible += 1
	return visible / 3.0

func detonate_grenade(id: int) -> void:
	if not grenades.has(id):
		return
	var grenade = grenades[id]
	var origin: Vector3 = grenade.position + Vector3.UP * 0.04
	var attacker_id: int = grenade.owner_id
	grenades.erase(id)
	grenade.queue_free()
	if phase == "live":
		for actor in actors.values():
			if not actor.alive:
				continue
			var distance: float = actor.aim_position().distance_to(origin)
			if distance >= Grenade.RADIUS:
				continue
			var amount: float = Grenade.MAX_DAMAGE * (1 - distance / Grenade.RADIUS) * explosion_exposure(origin, actor)
			if amount > 0:
				damage(actor, amount, attacker_id, false, false, "FRAG", origin)
	if dedicated:
		for peer in sessions:
			if peer_ready(peer):
				grenade_exploded.rpc_id(peer, match_id, id, origin)
	else:
		grenade_exploded(match_id, id, origin)

@rpc("authority", "call_remote", "unreliable_ordered", 4)
func grenade_snapshot(packet: PackedByteArray) -> void:
	if dedicated:
		return
	var data: Dictionary = bytes_to_var(packet.decompress_dynamic(32768, FileAccess.COMPRESSION_DEFLATE))
	if data.round != network_round_id:
		return
	for state in data.states:
		if grenade_tombstones.has(state.id):
			continue
		if not grenades.has(state.id):
			var grenade = Grenade.new()
			grenade.process_mode = Node.PROCESS_MODE_PAUSABLE
			grenade.authoritative = false
			grenade.grenade_id = state.id
			grenade.position = state.p
			add_child(grenade)
			grenades[state.id] = grenade
		grenades[state.id].target_position = state.p
		grenades[state.id].fuse = state.f
		grenades[state.id].owner_id = state.owner
	for id in grenades.keys():
		if not data.ids.has(id):
			grenades[id].queue_free()
			grenades.erase(id)

@rpc("authority", "call_remote", "reliable")
func grenade_exploded(round_id: String, id: int, origin: Vector3) -> void:
	if dedicated or (online and round_id != network_round_id):
		return
	if bot_client:
		test_grenade_exploded = true
	grenade_tombstones[id] = true
	if grenades.has(id):
		grenades[id].queue_free()
		grenades.erase(id)
	var effect := BlastEffect.new()
	effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	effect.position = origin
	add_child(effect)
	sound.shot(origin, 3)

func compatible_build(remote) -> bool:
	return remote is Dictionary and remote.get("protocol") == build_info.protocol and remote.get("content_revision") == build_info.content_revision

func ticket_payload(value: String) -> Dictionary:
	var payload := build_info.duplicate()
	payload.ticket = value
	return payload
