extends SceneTree
const Resampler = preload("res://scripts/voice_resampler.gd")

func tone(rate: int, frequency: float, frames: int) -> PackedVector2Array:
	var signal_frames := PackedVector2Array()
	for i in range(frames):
		signal_frames.append(Vector2.ONE * (0.5 * sin(TAU * frequency * i / rate)))
	return signal_frames

func energy(frames: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(32, frames.size()):
		total += frames[i].x * frames[i].x
	return sqrt(total / (frames.size() - 32))

func _initialize() -> void:
	for rate in [8000, 16000, 44100, 48000, 96000]:
		var data := tone(rate, 1000, 4096)
		var whole := Resampler.new(rate).push(data)
		var stream := Resampler.new(rate)
		var split := PackedVector2Array()
		var cursor := 0
		for count in [1, 19, 256, 7, 1000, 2813]:
			split.append_array(stream.push(data.slice(cursor, cursor + count)))
			cursor += count
		assert(cursor == 4096 and whole == split, "Capture chunk boundaries must not change audio")
		assert(absf(whole.size() - float(4096 - 16) * 16000 / rate) <= 2)
		assert(absf(energy(whole) - sqrt(0.125)) < 0.015)
		assert(stream.samples.size() <= 40)
	var high := Resampler.new(48000).push(tone(48000, 12000, 4096))
	assert(energy(high) < 0.02, "Reject frequencies that would alias into the speech band")
	var huge := PackedVector2Array()
	huge.resize(8193)
	var resetter := Resampler.new()
	assert(resetter.push(huge).is_empty() and resetter.samples.size() == 16)
	print("VOICE_RESAMPLER_PASS rates=5 chunk_equivalence=exact amplitude=ok alias_rejection=ok bounded_memory=ok stale_capture_reset=ok")
	quit()
