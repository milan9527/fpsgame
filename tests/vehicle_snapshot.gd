extends SceneTree
const Wire = preload("res://scripts/vehicle_snapshot.gd")
const ROUND := "12345678-1234-4234-8234-123456789abc"
const OTHER := "22345678-1234-4234-8234-123456789abc"

func _initialize() -> void:
	call_deferred("run")

func state(id: int) -> Dictionary:
	return {"id": id, "epoch": 17, "ack": 99, "p": Vector3(id, 0.01, -id),
		"yaw": 0.3, "vel": Vector3(2, -0.4, 3), "speed": 3.2, "steering": -0.2,
		"health": 432.125, "fuel": 61.75, "wheels": [0.1, 0.2, 0.3, 0.4],
		"driver": id, "seats": [id, -id], "grounded": true, "destroyed": false}

func run() -> void:
	var states: Array = []
	for id in range(1, 33):
		states.append(state(id))
	var packets := Wire.encode(ROUND, 42, states)
	assert(packets.size() == 4)
	for packet in packets:
		assert(packet.size() == 732 and packet.size() < 1150)
	var receiver = Wire.new()
	receiver.reset(ROUND)
	assert(receiver.receive(packets[3], 0).is_empty())
	assert(receiver.receive(packets[3], 1).is_empty())
	assert(receiver.receive(packets[1], 2).is_empty())
	assert(receiver.receive(packets[0], 3).is_empty())
	var restored: Dictionary = receiver.receive(packets[2], 4)
	assert(restored.sequence == 42 and restored.states.size() == 32 and receiver.pending.is_empty())
	for index in range(32):
		var decoded: Dictionary = restored.states[index]
		assert(decoded.id == states[index].id and decoded.seats == states[index].seats)
		assert(decoded.p.distance_to(states[index].p) < 0.00001)
		assert(is_equal_approx(decoded.health, states[index].health) and decoded.epoch == 17 and decoded.ack == 99)
	assert(receiver.receive(packets[0], 5).is_empty())
	assert(receiver.receive(Wire.encode(OTHER, 43, states)[0], 6).is_empty())
	assert(receiver.pending.is_empty())
	# Two overlapping snapshots are assembled independently; older complete
	# frames cannot replace an already applied newer frame.
	var newer := Wire.encode(ROUND, 44, states)
	var older := Wire.encode(ROUND, 43, states)
	receiver.receive(older[0], 10)
	receiver.receive(newer[0], 11)
	receiver.receive(older[1], 12)
	receiver.receive(newer[1], 13)
	receiver.receive(newer[2], 14)
	assert(receiver.receive(newer[3], 15).sequence == 44)
	assert(receiver.receive(older[2], 16).is_empty() and receiver.last_sequence == 44)
	receiver.reset(ROUND)
	receiver.receive(packets[0], 0)
	receiver.receive(packets[1], 251)
	assert(receiver.pending[42].parts.size() == 1, "Expired chunks must not complete a stale batch")
	for seq in range(43, 60):
		receiver.receive(Wire.encode(ROUND, seq, states)[0], 252)
		assert(receiver.pending.size() <= 2)
	# Empty fleet is a complete snapshot, allowing authoritative cleanup.
	var empty := Wire.encode(ROUND, 100, [])
	assert(empty.size() == 1 and empty[0].size() == Wire.HEADER)
	assert(receiver.receive(empty[0], 300).states.is_empty())
	receiver.reset(OTHER)
	assert(receiver.last_sequence == -1 and receiver.pending.is_empty())
	assert(receiver.receive(packets[0], 301).is_empty())
	# Encoder rejects inconsistent authority state.
	var invalid := states.duplicate(true)
	invalid[1].seats[0] = invalid[0].seats[0]
	assert(Wire.encode(ROUND, 1, invalid).is_empty())
	invalid = states.duplicate(true)
	invalid[0].destroyed = true
	assert(Wire.encode(ROUND, 1, invalid).is_empty())
	invalid = states.duplicate(true)
	invalid[0].p.x = NAN
	assert(Wire.encode(ROUND, 1, invalid).is_empty())
	assert(Wire.encode("invalid-round", 1, states).is_empty())
	assert(Wire.encode(ROUND, -1, states).is_empty())
	# Reject truncation, trailing bytes, unknown flags, NaNs and impossible IDs.
	for length in range(packets[0].size()):
		assert(Wire.decode(packets[0].slice(0, length)).is_empty())
	var bad := packets[0].duplicate()
	bad.append(0)
	assert(Wire.decode(bad).is_empty())
	for offset in [2, 7, Wire.HEADER + 80, Wire.HEADER + 81]:
		bad = packets[0].duplicate()
		bad[offset] = 255
		assert(Wire.decode(bad).is_empty())
	bad = packets[0].duplicate()
	bad.encode_float(Wire.HEADER + 44, NAN)
	assert(Wire.decode(bad).is_empty())
	bad = packets[0].duplicate()
	bad.encode_u32(Wire.HEADER, 0xffffffff)
	assert(Wire.decode(bad).is_empty())
	# A duplicate occupant can straddle packet boundaries.
	receiver.reset(ROUND)
	bad = packets[1].duplicate()
	bad.encode_s32(Wire.HEADER + 68, 1)
	bad.encode_s32(Wire.HEADER + 72, 1)
	receiver.receive(packets[0], 0)
	receiver.receive(bad, 1)
	receiver.receive(packets[2], 2)
	assert(receiver.receive(packets[3], 3).is_empty() and receiver.last_sequence == -1)
	# Conflicting retransmission of one chunk discards its partial batch.
	receiver.receive(packets[0], 4)
	bad = packets[0].duplicate()
	bad.encode_float(Wire.HEADER + 48, 50)
	assert(receiver.receive(bad, 5).is_empty() and receiver.pending.is_empty())
	var rng := RandomNumberGenerator.new()
	rng.seed = 93281
	for _trial in range(1000):
		var noise := PackedByteArray()
		noise.resize(rng.randi_range(0, Wire.MAX_BYTES + 16))
		for index in range(noise.size()):
			noise[index] = rng.randi_range(0, 255)
		assert(Wire.decode(noise).is_empty())
	# The real fleet uses the same fields, including negative bot IDs.
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.volume = 0
	await physics_frame
	await physics_frame
	game._physics_process(1.0 / 60)
	var live: Array = Wire.capture(game.vehicle_fleet)
	assert(live.size() == 4 and Wire.encode(game.match_id, 0, live).size() == 1)
	game.running = false
	game.queue_free()
	await process_frame
	print("VEHICLE_SNAPSHOT_PASS fixed_bytes=ok fleet32=ok precision=ok reordered_chunks=ok stale_round=ok overlapping_frames=ok timeout=ok bounded_memory=ok empty_fleet=ok invalid_state=ok malformed_packets=ok duplicate_seats=ok fuzz1000=ok real_fleet=ok")
	quit()
