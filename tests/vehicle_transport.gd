extends SceneTree

# Transport fixture only: admission is deliberately omitted. Both processes use
# the production Game RPCs and frame pairing; fixture RPCs advance assertions.
class Fixture:
	extends "res://scripts/game.gd"
	const ROUND := "12345678-1234-4234-8234-123456789abc"
	var stage := 0
	var reported := -1
	var ticks := 0
	func _ready() -> void:
		dedicated = "--fixture-server" in OS.get_cmdline_user_args()
		online = not dedicated
		local_id = 999
		match_id = ROUND
		network_round_id = ROUND
		phase = "live"
		vehicle_frames.reset(ROUND)
		vehicle_replica.reset(self, ROUND)
		last_loot_hash = loot.hash()
		var peer := ENetMultiplayerPeer.new()
		var port := int(OS.get_environment("VEHICLE_TEST_PORT"))
		if dedicated:
			assert(peer.create_server(port, 2) == OK)
			multiplayer.peer_connected.connect(func(id): sessions[id] = {})
			for id in range(1, 17):
				spawn_actor(id, "Transport-%d" % id, false, Vector3(id, 0, 10))
			var car = vehicle_fleet.spawn(self, Vector3.ZERO)
			for index in range(2):
				var actor = actors[index + 1]
				car.seats.slots[index] = {"actor": weakref(actor), "mask": actor.collision_mask, "layer": actor.collision_layer}
				actor.vehicle_ref = weakref(car)
				actor.vehicle_seat = index
				actor.collision_mask = 0
				car.add_collision_exception_with(actor)
				car.seats.sync_actor(actor, index)
			car.seats.epoch = 1
			car.driver_id = 1
		else:
			assert(peer.create_client("127.0.0.1", port) == OK)
		multiplayer.multiplayer_peer = peer

	func _process(dt: float) -> void:
		if not dedicated:
			vehicle_replica.render(self, dt)

	func _physics_process(_dt: float) -> void:
		ticks += 1
		assert(ticks < 900, "Transport fixture timed out")
		if dedicated:
			if ticks % 3 == 0:
				events = [str(stage)]
				broadcast_snapshot()
			return
		if events.is_empty() or vehicle_replica.last_sequence < 0:
			return
		var observed := int(events[0])
		if observed == reported:
			return
		assert(actors.size() == 16, "All four actor chunks must arrive before application")
		if observed in [0, 1]:
			assert(vehicle_fleet.vehicles.size() == 1)
			var car = vehicle_fleet.vehicles[1]
			assert(not car.authoritative and car.driver_id == 1)
			assert(actors[1].is_seated() and actors[2].is_seated())
			assert(actors[1].vehicle_seat == 0 and actors[2].vehicle_seat == 1)
			if observed == 1:
				assert(vehicle_replica.targets[1].p.x == 8)
				assert(car.fuel == 42)
		else:
			assert(vehicle_fleet.vehicles.is_empty())
			assert(not actors[1].is_seated() and not actors[2].is_seated())
			assert(actors[1].collision_mask == 7)
		reported = observed
		stage_seen.rpc_id(1, observed)
		if observed == 2:
			print("VEHICLE_TRANSPORT_CLIENT_PASS actors16=ok production_rpc=ok seats=ok movement=ok fuel=ok removal=ok")

	@rpc("any_peer", "call_remote", "reliable")
	func stage_seen(observed: int) -> void:
		assert(dedicated and sessions.has(multiplayer.get_remote_sender_id()))
		if observed != stage:
			return
		if stage == 0:
			var car = vehicle_fleet.vehicles[1]
			car.position.x = 8
			car.fuel = 42
			for index in range(2):
				car.seats.sync_actor(actors[index + 1], index)
		elif stage == 1:
			vehicle_fleet.clear()
			actors[1].position = Vector3(7, 0, 3)
			actors[2].position = Vector3(9, 0, 3)
		else:
			print("VEHICLE_TRANSPORT_SERVER_PASS acknowledged_stages=3")
			finish.rpc()
			await get_tree().create_timer(0.3).timeout
			multiplayer.multiplayer_peer.close()
			get_tree().quit()
		stage += 1

	@rpc("authority", "call_remote", "reliable")
	func finish() -> void:
		assert(reported == 2)
		multiplayer.multiplayer_peer.close()
		get_tree().quit()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = Fixture.new()
	game.name = "Game"
	root.add_child(game)
