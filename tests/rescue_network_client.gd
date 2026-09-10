extends SceneTree
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
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	deadline = Time.get_ticks_msec() + 45000
	while not game.running:
		assert(Time.get_ticks_msec() < deadline)
		await process_frame
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
	var observed_knock := false
	var observed_progress := false
	var observed_revive := false
	var interrupts := 0
	var active := false
	var requests := 0
	var request_due := 0
	while game.phase != "finished":
		assert(Time.get_ticks_msec() < deadline, "Network rescue scenario timed out")
		await process_frame
		if patient.downed:
			observed_knock = true
			assert(patient.alive and patient.health == 0 and patient.bleed_left > 0)
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
	assert(patient.rank == 1 and helper.rank == 1 and patient.kills == 2)
	for actor in game.actors.values():
		if actor.actor_id > 0 and actor.team_id == 2:
			assert(not actor.alive and actor.rank == 2)
	if game.local_id == helper_id:
		assert(requests == 3)
	print("RESCUE_NETWORK_CLIENT_PASS peer=%d knock=replicated progress=replicated interrupts=2 revived=replicated team_results=replicated" % game.local_id)
	await create_timer(1).timeout
	game.request_quit()
