extends SceneTree

var game
var next_report := 0

func _initialize() -> void:
	game = load("res://scripts/game.gd").new()
	game.name = "Game"
	root.add_child.call_deferred(game)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if game == null or now < next_report:
		return false
	next_report = now + 2000
	var info := {"msec": now, "running": game.running, "online": game.online,
		"actors": game.actors.size(), "test_seconds": game.bot_test_timer}
	if game.online and game.multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var peer: ENetPacketPeer = game.multiplayer.multiplayer_peer.get_peer(1)
		if peer != null:
			info["address"] = peer.get_remote_address()
			info["state"] = peer.get_state()
			info["rtt"] = peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	print("WINDOWS_NETWORK_OBSERVATION ", JSON.stringify(info))
	return false
