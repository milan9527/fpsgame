extends RefCounted

const Wire = preload("res://scripts/vehicle_snapshot.gd")
var wire = Wire.new()
var round_id := ""
var last_sequence := -1
var actor_frames: Dictionary = {}
var vehicle_frames: Dictionary = {}

func reset(current_round: String) -> void:
	round_id = current_round
	last_sequence = -1
	actor_frames.clear()
	vehicle_frames.clear()
	wire.reset(current_round)

func expire(now: int) -> void:
	for collection in [actor_frames, vehicle_frames]:
		for sequence in collection.keys():
			if now - collection[sequence].started > 250:
				collection.erase(sequence)

func reserve(collection: Dictionary, sequence: int) -> bool:
	if collection.has(sequence):
		return true
	if collection.size() >= 2:
		var oldest: int = collection.keys().min()
		if sequence < oldest:
			return false
		collection.erase(oldest)
	return true

func offer_actors(payload: Dictionary, now: int) -> bool:
	expire(now)
	var sequence = payload.get("frame_seq")
	if now < 0 or payload.get("round_id") != round_id or not Wire.valid_round(round_id) or not Wire.identifier(sequence) or sequence <= last_sequence:
		return false
	if not payload.get("actors") is Array or payload.actors.size() > 4 or not payload.get("roster") is Array or payload.roster.size() > 16:
		return false
	var roster := {}
	for id in payload.roster:
		if not Wire.identifier(id, -2147483647) or id == 0 or roster.has(id):
			return false
		roster[id] = true
	var chunk_ids := {}
	for actor in payload.actors:
		if not actor is Dictionary or not actor.has("id") or not roster.has(actor.id) or chunk_ids.has(actor.id):
			return false
		if not actor.get("p") is Vector3 or not actor.p.is_finite() or actor.p.length() >= 1000:
			return false
		chunk_ids[actor.id] = true
	var meta := payload.duplicate(true)
	meta.erase("actors")
	if not reserve(actor_frames, sequence):
		return false
	if not actor_frames.has(sequence):
		actor_frames[sequence] = {"started": now, "meta": meta, "actors": {}}
	var frame: Dictionary = actor_frames[sequence]
	if frame.meta != meta:
		actor_frames.erase(sequence)
		return false
	for actor in payload.actors:
		if frame.actors.has(actor.id) and frame.actors[actor.id] != actor:
			actor_frames.erase(sequence)
			return false
		frame.actors[actor.id] = actor.duplicate(true)
	return true

func offer_vehicles(packet: PackedByteArray, now: int) -> void:
	expire(now)
	var frame: Dictionary = wire.receive(packet, now)
	if frame.is_empty() or frame.sequence <= last_sequence or not reserve(vehicle_frames, frame.sequence):
		return
	vehicle_frames[frame.sequence] = {"started": now, "frame": frame}

func take_pair() -> Dictionary:
	var best := -1
	for sequence in vehicle_frames:
		if not actor_frames.has(sequence):
			continue
		var actors: Dictionary = actor_frames[sequence]
		if actors.actors.size() == actors.meta.roster.size() and sequence > best:
			best = sequence
	if best < 0:
		return {}
	var actor_frame: Dictionary = actor_frames[best]
	var payload: Dictionary = actor_frame.meta.duplicate(true)
	payload.actors = []
	var positions := {}
	for id in payload.roster:
		payload.actors.append(actor_frame.actors[id])
		positions[id] = actor_frame.actors[id].p
	var result := {"payload": payload, "vehicles": vehicle_frames[best].frame,
		"poses": {"round": round_id, "sequence": best, "positions": positions}}
	last_sequence = best
	for collection in [actor_frames, vehicle_frames]:
		for sequence in collection.keys():
			if sequence <= best:
				collection.erase(sequence)
	return result
