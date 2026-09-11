extends RefCounted

# Independently decodable mono IMA ADPCM packets: 20 ms at 16 kHz.
# Header: signed PCM16 predictor, step index, format version. Low nibble first.
const RATE := 16000
const FRAMES := 320
const BYTES := 164
const VERSION := 1
const STEPS := [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
const INDICES := [-1,-1,-1,-1,2,4,6,8]

static func pcm(frame: Vector2) -> int:
	var mono := (frame.x + frame.y) * 0.5
	return clampi(roundi(mono * 32767.0), -32768, 32767) if is_finite(mono) else 0

static func encode(frames: PackedVector2Array) -> PackedByteArray:
	if frames.size() != FRAMES:
		return PackedByteArray()
	var predictor := pcm(frames[0])
	var slope := 0
	for i in range(1, 32):
		slope += absi(pcm(frames[i]) - pcm(frames[i - 1]))
	slope = maxi(7, int(slope / 31))
	var index := 0
	while index < 88 and STEPS[index] < slope:
		index += 1
	var output := PackedByteArray()
	output.resize(BYTES)
	output.encode_s16(0, predictor)
	output[2] = index
	output[3] = VERSION
	for i in range(1, FRAMES):
		var step: int = STEPS[index]
		var delta := pcm(frames[i]) - predictor
		var nibble := 8 if delta < 0 else 0
		delta = absi(delta)
		var change := step >> 3
		for bit in [4, 2, 1]:
			if delta >= step:
				nibble |= bit
				delta -= step
				change += step
			step >>= 1
		predictor = clampi(predictor + (-change if nibble & 8 else change), -32768, 32767)
		index = clampi(index + INDICES[nibble & 7], 0, 88)
		var offset := 4 + int((i - 1) / 2)
		output[offset] |= nibble << (4 * ((i - 1) % 2))
	return output

static func valid(packet: PackedByteArray) -> bool:
	return packet.size() == BYTES and packet[2] <= 88 and packet[3] == VERSION and (packet[BYTES - 1] & 0xf0) == 0

static func decode(packet: PackedByteArray) -> PackedVector2Array:
	if not valid(packet):
		return PackedVector2Array()
	var predictor := packet.decode_s16(0)
	var index: int = packet[2]
	var output := PackedVector2Array()
	output.resize(FRAMES)
	output[0] = Vector2.ONE * (predictor / 32768.0)
	for i in range(1, FRAMES):
		var nibble: int = (packet[4 + int((i - 1) / 2)] >> (4 * ((i - 1) % 2))) & 15
		var step: int = STEPS[index]
		var change := step >> 3
		if nibble & 4:
			change += step
		if nibble & 2:
			change += step >> 1
		if nibble & 1:
			change += step >> 2
		predictor = clampi(predictor + (-change if nibble & 8 else change), -32768, 32767)
		index = clampi(index + INDICES[nibble & 7], 0, 88)
		output[i] = Vector2.ONE * (predictor / 32768.0)
	return output
