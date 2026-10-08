extends SceneTree


func _initialize() -> void:
	# The room sends a bounded 20 Hz stream with atomic multi-packet snapshots.
	# RTT spikes during scene loading must not make ENet deliberately discard
	# individual chunks: one missing chunk prevents the entire frame applying.
	get_multiplayer().peer_connected.connect(_configure_snapshot_peer)
	change_scene_to_file("res://main.tscn")


func _configure_snapshot_peer(id: int) -> void:
	if not get_multiplayer().is_server():
		return
	var transport := get_multiplayer().multiplayer_peer as ENetMultiplayerPeer
	if transport == null:
		return
	transport.get_peer(id).throttle_configure(5000, 2, 0)
