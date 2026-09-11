extends RefCounted

# Fixed-width, little-endian vehicle state. No Variant/object deserialization.
const MAGIC := 0x5649
const VERSION := 1
const HEADER := 28
const RECORD := 88
const PER_PACKET := 8
const MAX_VEHICLES := 32
const MAX_BYTES := HEADER + PER_PACKET * RECORD
var expected_round := ""
var last_sequence := -1
var pending: Dictionary = {}

static func number(value, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

static func identifier(value, low := 0) -> bool:
	return value is int and value >= low and value <= 2147483647

static func valid_round(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
	return regex.search(value) != null

static func valid_states(states: Array) -> bool:
	if states.size() > MAX_VEHICLES:
		return false
	var ids := {}
	var occupants := {}
	for state in states:
		if not state is Dictionary or not identifier(state.get("id"), 1) or ids.has(state.id) or not identifier(state.get("epoch")) or not identifier(state.get("ack"), -1):
			return false
		ids[state.id] = true
		if not state.get("p") is Vector3 or not state.p.is_finite() or absf(state.p.x) > 120 or absf(state.p.z) > 120 or state.p.y < -20 or state.p.y > 100:
			return false
		if not state.get("vel") is Vector3 or not state.vel.is_finite() or state.vel.length() > 120:
			return false
		if not number(state.get("yaw"), -PI - 0.001, PI + 0.001) or not number(state.get("speed"), -7.01, 22.01) or not number(state.get("steering"), -0.49, 0.49):
			return false
		if not number(state.get("health"), 0, 600) or not number(state.get("fuel"), 0, 100):
			return false
		if not state.get("grounded") is bool or not state.get("destroyed") is bool or state.destroyed != (state.health == 0):
			return false
		if not state.get("seats") is Array or state.seats.size() != 2 or not identifier(state.get("driver"), -2147483647):
			return false
		for occupant in state.seats:
			if not identifier(occupant, -2147483647):
				return false
			if occupant != 0:
				if occupants.has(occupant):
					return false
				occupants[occupant] = true
		if state.driver != 0 and (state.driver != state.seats[0] or state.destroyed):
			return false
		if not state.get("wheels") is Array or state.wheels.size() != 4:
			return false
		for angle in state.wheels:
			if not number(angle, -PI - 0.001, PI + 0.001):
				return false
	return true

static func capture(fleet) -> Array:
	var states: Array = []
	for id in fleet.vehicles:
		var car = fleet.vehicles[id]
		var seats: Array = []
		var wheels: Array = []
		for index in range(2):
			var actor = car.seats.occupant(index)
			seats.append(actor.actor_id if actor != null else 0)
		for wheel in car.wheel_rigs:
			wheels.append(float(wheel.roll.rotation.x))
		states.append({"id": id, "epoch": car.seats.epoch, "ack": car.input_sequence,
			"p": car.position, "yaw": car.rotation.y, "vel": car.velocity, "speed": car.speed,
			"steering": car.steering, "health": car.health, "fuel": car.fuel,
			"grounded": car.grounded, "destroyed": car.destroyed, "driver": car.driver_id,
			"seats": seats, "wheels": wheels})
	return states

static func encode(round_id: String, sequence: int, states: Array) -> Array[PackedByteArray]:
	var packets: Array[PackedByteArray] = []
	if not valid_round(round_id) or not identifier(sequence) or not valid_states(states):
		return packets
	var compact := round_id.replace("-", "")
	var chunks := maxi(1, ceili(float(states.size()) / PER_PACKET))
	for chunk in range(chunks):
		var count := mini(PER_PACKET, states.size() - chunk * PER_PACKET)
		var bytes := PackedByteArray()
		bytes.resize(HEADER + count * RECORD)
		bytes.fill(0)
		bytes.encode_u16(0, MAGIC)
		bytes[2] = VERSION
		bytes[3] = count
		bytes[4] = states.size()
		bytes[5] = chunk
		bytes[6] = chunks
		bytes.encode_u32(8, sequence)
		for index in range(16):
			bytes[12 + index] = compact.substr(index * 2, 2).hex_to_int()
		for index in range(count):
			var state: Dictionary = states[chunk * PER_PACKET + index]
			var offset := HEADER + index * RECORD
			bytes.encode_u32(offset, state.id)
			bytes.encode_u32(offset + 4, state.epoch)
			var values: Array = [state.p.x, state.p.y, state.p.z, state.yaw,
				state.vel.x, state.vel.y, state.vel.z, state.speed, state.steering, state.health, state.fuel]
			values.append_array(state.wheels)
			for field in range(values.size()):
				bytes.encode_float(offset + 8 + field * 4, values[field])
			bytes.encode_s32(offset + 68, state.driver)
			bytes.encode_s32(offset + 72, state.seats[0])
			bytes.encode_s32(offset + 76, state.seats[1])
			bytes[offset + 80] = (1 if state.grounded else 0) | (2 if state.destroyed else 0)
			bytes.encode_s32(offset + 84, state.ack)
		packets.append(bytes)
	return packets

static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER or bytes.size() > MAX_BYTES:
		return {}
	if bytes.decode_u16(0) != MAGIC or bytes[2] != VERSION or bytes[7] != 0:
		return {}
	var count := int(bytes[3])
	var total := int(bytes[4])
	var chunk := int(bytes[5])
	var chunks := int(bytes[6])
	if total > MAX_VEHICLES or chunks != maxi(1, ceili(float(total) / PER_PACKET)) or chunk >= chunks:
		return {}
	if count != mini(PER_PACKET, total - chunk * PER_PACKET) or bytes.size() != HEADER + count * RECORD:
		return {}
	var sequence := int(bytes.decode_u32(8))
	if not identifier(sequence):
		return {}
	var uuid := bytes.slice(12, 28).hex_encode()
	var round_id := "%s-%s-%s-%s-%s" % [uuid.substr(0, 8), uuid.substr(8, 4), uuid.substr(12, 4), uuid.substr(16, 4), uuid.substr(20, 12)]
	var states: Array = []
	for index in range(count):
		var offset := HEADER + index * RECORD
		var flags := int(bytes[offset + 80])
		if flags > 3 or bytes[offset + 81] != 0 or bytes[offset + 82] != 0 or bytes[offset + 83] != 0:
			return {}
		var values: Array[float] = []
		for field in range(15):
			values.append(bytes.decode_float(offset + 8 + field * 4))
		states.append({"id": int(bytes.decode_u32(offset)), "epoch": int(bytes.decode_u32(offset + 4)),
			"p": Vector3(values[0], values[1], values[2]), "yaw": values[3],
			"vel": Vector3(values[4], values[5], values[6]), "speed": values[7], "steering": values[8],
			"health": values[9], "fuel": values[10], "wheels": [values[11], values[12], values[13], values[14]],
			"driver": bytes.decode_s32(offset + 68), "seats": [bytes.decode_s32(offset + 72), bytes.decode_s32(offset + 76)],
			"grounded": (flags & 1) != 0, "destroyed": (flags & 2) != 0, "ack": bytes.decode_s32(offset + 84)})
	if not valid_states(states):
		return {}
	return {"round": round_id, "sequence": sequence, "total": total, "chunk": chunk, "chunks": chunks, "states": states}

func reset(round_id: String) -> void:
	expected_round = round_id if valid_round(round_id) else ""
	last_sequence = -1
	pending.clear()

func receive(bytes: PackedByteArray, now_msec: int) -> Dictionary:
	for sequence in pending.keys():
		if now_msec - pending[sequence].started > 250:
			pending.erase(sequence)
	var packet := decode(bytes)
	if packet.is_empty() or expected_round == "" or packet.round != expected_round or packet.sequence <= last_sequence or now_msec < 0:
		return {}
	var sequence: int = packet.sequence
	if not pending.has(sequence):
		if pending.size() >= 2:
			var oldest: int = pending.keys().min()
			if sequence < oldest:
				return {}
			pending.erase(oldest)
		pending[sequence] = {"started": now_msec, "total": packet.total, "count": packet.chunks, "parts": {}, "bytes": {}}
	var batch: Dictionary = pending[sequence]
	if batch.total != packet.total or batch.count != packet.chunks:
		pending.erase(sequence)
		return {}
	if batch.parts.has(packet.chunk):
		if batch.bytes[packet.chunk] != bytes:
			pending.erase(sequence)
		return {}
	batch.parts[packet.chunk] = packet.states
	batch.bytes[packet.chunk] = bytes.duplicate()
	if batch.parts.size() != batch.count:
		return {}
	var states: Array = []
	for chunk in range(batch.count):
		states.append_array(batch.parts[chunk])
	pending.erase(sequence)
	if states.size() != batch.total or not valid_states(states):
		return {}
	last_sequence = sequence
	for old in pending.keys():
		if old <= sequence:
			pending.erase(old)
	return {"round": expected_round, "sequence": sequence, "states": states}
