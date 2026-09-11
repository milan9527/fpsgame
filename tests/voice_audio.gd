extends SceneTree
const Codec = preload("res://scripts/voice_codec.gd")
const Jitter = preload("res://scripts/voice_jitter.gd")

func _initialize() -> void:
	var frames := PackedVector2Array()
	for i in range(Codec.FRAMES):
		var value := 0.6 * sin(TAU * 440 * i / Codec.RATE) + 0.15 * sin(TAU * 1300 * i / Codec.RATE)
		frames.append(Vector2.ONE * value)
	var packet := Codec.encode(frames)
	assert(packet.size() == 164 and Codec.valid(packet))
	var decoded := Codec.decode(packet)
	assert(decoded.size() == 320)
	var squared_error := 0.0
	for i in range(320):
		assert(decoded[i].is_finite() and decoded[i].x == decoded[i].y)
		squared_error += pow(decoded[i].x - frames[i].x, 2)
	var rms := sqrt(squared_error / 320)
	assert(rms < 0.025, "Voice fixture quantization error must stay bounded")
	for size in [0, 3, 163, 165, 1000]:
		var bad := PackedByteArray()
		bad.resize(size)
		assert(Codec.decode(bad).is_empty())
	for field in [2, 3, 163]:
		var bad := packet.duplicate()
		bad[field] = 255
		assert(Codec.decode(bad).is_empty())
	var silence := PackedVector2Array()
	silence.resize(320)
	silence[0] = Vector2(INF, NAN)
	var quiet := Codec.decode(Codec.encode(silence))
	for frame in quiet:
		assert(frame == Vector2.ZERO)
	var buffer := Jitter.new()
	assert(buffer.push(10, packet, 0))
	assert(buffer.push(12, packet, 40))
	assert(buffer.push(11, packet, 45))
	assert(not buffer.push(11, packet, 46))
	assert(not buffer.push(30, packet, 46))
	assert(buffer.pull(59).is_empty())
	for at in [60, 80, 100]:
		assert(buffer.pull(at) == decoded)
	assert(not buffer.push(10, packet, 101))
	var conceal := buffer.pull(120)
	assert(conceal.size() == 320 and conceal[-1] == Vector2.ZERO)
	for at in [140, 160, 180, 200]:
		assert(buffer.pull(at).size() == 320)
	assert(buffer.next_sequence == -1 and buffer.packets.is_empty())
	assert(buffer.push(100, packet, 600))
	assert(buffer.pull(1000).is_empty() and buffer.packets.is_empty())
	# Export only a synthetic tone for independent decoder verification.
	var file := FileAccess.open("res://../artifacts/voice-codec-test.bin", FileAccess.WRITE)
	file.store_buffer(packet)
	file.close()
	file = FileAccess.open("res://../artifacts/voice-decoded-test.bin", FileAccess.WRITE)
	for frame in decoded:
		file.store_16(int(round(frame.x * 32768.0)) & 0xffff)
	file.close()
	print("VOICE_AUDIO_PASS independent_packets=ok rms=%f size=164 malformed=ok reorder=ok replay=ok loss_fade=ok bounded_buffer=ok stalled_reset=ok" % rms)
	quit()
