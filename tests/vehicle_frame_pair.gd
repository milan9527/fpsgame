extends SceneTree
const Pair = preload("res://scripts/vehicle_frame_pair.gd")
const Wire = preload("res://scripts/vehicle_snapshot.gd")
const ROUND := "12345678-1234-4234-8234-123456789abc"

func chunk(sequence: int, ids: Array, roster: Array = [1, 2]) -> Dictionary:
	var actors := []
	for id in ids:
		actors.append({"id": id, "p": Vector3(id, 0, 0)})
	return {"round_id": ROUND, "frame_seq": sequence, "actors": actors,
		"roster": roster, "phase": "live"}

func _initialize() -> void:
	var pair = Pair.new()
	pair.reset(ROUND)
	pair.offer_vehicles(Wire.encode(ROUND, 1, [])[0], 0)
	assert(pair.offer_actors(chunk(1, [2]), 1))
	assert(pair.take_pair().is_empty(), "Never expose a partially received actor roster")
	assert(pair.offer_actors(chunk(1, [1]), 2))
	var result: Dictionary = pair.take_pair()
	assert(result.payload.actors[0].id == 1 and result.payload.actors[1].id == 2)
	assert(result.poses.sequence == 1 and result.vehicles.sequence == 1)
	assert(result.poses.positions[2] == Vector3(2, 0, 0))
	assert(not pair.offer_actors(chunk(1, [1, 2]), 3))
	assert(pair.offer_actors(chunk(2, [1, 2]), 4))
	assert(pair.take_pair().is_empty())
	pair.offer_vehicles(Wire.encode(ROUND, 3, [])[0], 5)
	assert(pair.take_pair().is_empty(), "Different sequence numbers cannot form a frame")
	assert(pair.offer_actors(chunk(3, [1, 2]), 6))
	assert(pair.take_pair().poses.sequence == 3)
	assert(pair.actor_frames.is_empty() and pair.vehicle_frames.is_empty())
	pair.reset(ROUND)
	assert(pair.offer_actors(chunk(4, [1]), 0))
	pair.offer_vehicles(Wire.encode(ROUND, 4, [])[0], 251)
	assert(pair.offer_actors(chunk(4, [2]), 252))
	assert(pair.take_pair().is_empty(), "Expired actor fragments must be discarded")
	pair.reset(ROUND)
	for sequence in range(10, 30):
		assert(pair.offer_actors(chunk(sequence, [1]), 0))
		pair.offer_vehicles(Wire.encode(ROUND, sequence, [])[0], 0)
		assert(pair.actor_frames.size() <= 2 and pair.vehicle_frames.size() <= 2)
	assert(not pair.offer_actors(chunk(10, [2]), 1))
	assert(pair.offer_actors(chunk(29, [2]), 2))
	assert(pair.take_pair().poses.sequence == 29)
	pair.reset(ROUND)
	assert(pair.offer_actors(chunk(30, [1]), 0))
	var conflict := chunk(30, [2])
	conflict.phase = "finished"
	assert(not pair.offer_actors(conflict, 1) and pair.actor_frames.is_empty())
	assert(pair.offer_actors(chunk(31, [1]), 2))
	conflict = chunk(31, [1])
	conflict.actors[0].p.x += 1
	assert(not pair.offer_actors(conflict, 3) and pair.actor_frames.is_empty())
	assert(not pair.offer_actors(chunk(32, [1], [1, 1]), 4))
	assert(not pair.offer_actors(chunk(32, [1, 1]), 4))
	assert(not pair.offer_actors(chunk(32, [3]), 4))
	conflict = chunk(32, [1, 2])
	conflict.round_id = "22345678-1234-4234-8234-123456789abc"
	assert(not pair.offer_actors(conflict, 4))
	assert(pair.offer_actors(chunk(33, [], []), 5))
	pair.offer_vehicles(Wire.encode(ROUND, 33, [])[0], 6)
	assert(pair.take_pair().payload.actors.is_empty())
	pair.reset(ROUND)
	assert(pair.last_sequence == -1 and pair.actor_frames.is_empty() and pair.vehicle_frames.is_empty())
	print("VEHICLE_FRAME_PAIR_PASS reordered=ok incomplete=ok sequence=ok expiry=ok bounded=ok conflict=ok roster=ok empty=ok reset=ok")
	quit()
