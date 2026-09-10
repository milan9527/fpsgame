extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var status = load("res://scripts/network_status.gd").new()
	assert(status.describe(0).text == "")
	status.begin(100)
	assert("SYNCING" in status.describe(100).text and "WAITING 0ms" in status.describe(100).text)
	status.sample(45, 8)
	status.received(101)
	assert("MEASURING" in status.describe(102).text)
	status.received(1100)
	assert(status.describe(1100).severity == 0 and "RTT 45ms / VAR 8ms" in status.describe(1100).text)
	status.sample(180, 8)
	assert(status.describe(1100).severity == 1 and "HIGH LATENCY" in status.describe(1100).text)
	status.sample(90, 60)
	assert("UNSTABLE" in status.describe(1100).text)
	status.sample(NAN, 0)
	status.sample(1, INF)
	status.sample(-1, 0)
	assert(status.rtt == 90 and status.variance == 60)
	assert(not status.describe(2099).stalled and status.describe(2100).stalled)
	status.received(2101)
	status.sample(45, 8)
	assert(not status.describe(2101).stalled and status.describe(2101).severity == 0)
	status.begin(3000)
	assert(status.last_snapshot == -1 and status.rtt == -1 and status.describe(4000).stalled)
	status.reset()
	assert(status.describe(5000).text.is_empty())
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	game.sound.volume = 0
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.update_network_status()
	assert(not game.ui.network_label.visible)
	await create_timer(1.6).timeout
	game.online = true
	game.network_round_id = "current"
	game.network_status.begin(Time.get_ticks_msec())
	var stale := {"round_id": "old"}
	game.snapshot(var_to_bytes(stale).compress(FileAccess.COMPRESSION_DEFLATE))
	assert(game.network_status.last_snapshot == -1, "Stale-round packets cannot refresh connection health")
	game.network_status.received(Time.get_ticks_msec() - 1500)
	game.update_network_status()
	assert(game.ui.network_label.visible and "SERVER UPDATES DELAYED" in game.ui.network_label.text)
	game.new_round("next")
	assert(game.network_status.last_snapshot == -1 and game.network_status.rtt == -1)
	game.leave()
	assert(not game.ui.network_label.visible and game.network_status.describe(Time.get_ticks_msec()).text == "")
	print("NETWORK_STATUS_RULES_PASS rtt=ok variance=ok initial_grace=ok stall=ok recovery=ok stale_round=ok lifecycle=ok")
	game.request_quit()
