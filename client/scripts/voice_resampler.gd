extends RefCounted

const RATE := 16000
const HALF := 16
const PHASES := 128
var input_rate := 48000
var samples := PackedFloat32Array()
var clock_units := HALF * RATE
var kernels: Array[PackedFloat32Array] = []

func _init(source_rate := 48000) -> void:
	assert(source_rate >= 8000 and source_rate <= 192000)
	input_rate = source_rate
	var cutoff := minf(7000.0, input_rate * 0.45) / input_rate
	for phase in range(PHASES):
		var weights := PackedFloat32Array()
		var total := 0.0
		for tap in range(-HALF + 1, HALF + 1):
			var x := float(tap) - float(phase) / PHASES
			var sinc := 2.0 * cutoff if absf(x) < 0.00001 else sin(TAU * cutoff * x) / (PI * x)
			var value := sinc * (0.5 + 0.5 * cos(PI * x / HALF))
			weights.append(value)
			total += value
		for i in range(weights.size()):
			weights[i] /= total
		kernels.append(weights)
	reset()

func reset() -> void:
	samples.resize(HALF)
	samples.fill(0.0)
	clock_units = HALF * RATE

func push(frames: PackedVector2Array) -> PackedVector2Array:
	# A caller must discard accumulated microphone audio after a stall.
	if frames.size() > 8192:
		reset()
		return PackedVector2Array()
	for frame in frames:
		var mono := (frame.x + frame.y) * 0.5
		samples.append(clampf(mono, -1.0, 1.0) if is_finite(mono) else 0.0)
	var output := PackedVector2Array()
	while int(clock_units / RATE) + HALF < samples.size():
		var center := int(clock_units / RATE)
		var phase := int((clock_units % RATE) * PHASES / RATE)
		var value := 0.0
		var weights := kernels[phase]
		for tap in range(weights.size()):
			value += samples[center - HALF + 1 + tap] * weights[tap]
		output.append(Vector2.ONE * clampf(value, -1.0, 1.0))
		clock_units += input_rate
	var consumed := maxi(0, int(clock_units / RATE) - HALF)
	if consumed > 0:
		samples = samples.slice(consumed)
		clock_units -= consumed * RATE
	return output
