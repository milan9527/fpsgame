extends RefCounted

const Codec = preload("res://scripts/voice_codec.gd")
const FRAME_MS := 20
const START_MS := 60
const MAX_PACKETS := 10
var packets: Dictionary = {}
var next_sequence := -1
var due := 0
var last_received := -1
var last_sample := Vector2.ZERO
var missed := 0

func reset() -> void:
	packets.clear()
	next_sequence = -1
	due = 0
	last_received = -1
	last_sample = Vector2.ZERO
	missed = 0

func push(sequence: int, packet: PackedByteArray, now: int) -> bool:
	if sequence < 0 or sequence > 2147483647 or not Codec.valid(packet):
		return false
	if last_received >= 0 and now - last_received > 500:
		reset()
	if next_sequence < 0:
		next_sequence = sequence
		due = now + START_MS
	if sequence < next_sequence or sequence >= next_sequence + MAX_PACKETS or packets.has(sequence):
		return false
	packets[sequence] = packet.duplicate()
	last_received = now
	return true

func pull(now: int) -> PackedVector2Array:
	if next_sequence < 0 or now < due:
		return PackedVector2Array()
	# Do not replay a backlog after a stalled renderer or an inactive device.
	if now - due > 200:
		reset()
		return PackedVector2Array()
	var frames: PackedVector2Array
	if packets.has(next_sequence):
		frames = Codec.decode(packets[next_sequence])
		packets.erase(next_sequence)
		missed = 0
	else:
		missed += 1
		frames.resize(Codec.FRAMES)
		for i in range(Codec.FRAMES):
			frames[i] = last_sample * maxf(0.0, 1.0 - float(i + 1) / 80.0)
	last_sample = frames[Codec.FRAMES - 1]
	next_sequence += 1
	due += FRAME_MS
	if missed >= 5 and packets.is_empty():
		reset()
	return frames
