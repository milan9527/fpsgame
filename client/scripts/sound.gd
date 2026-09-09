extends Node
var streams: Array[AudioStreamWAV] = []
var volume := 0.65

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 39
	for kind in range(3):
		var sound := AudioStreamWAV.new()
		sound.format = AudioStreamWAV.FORMAT_16_BITS
		sound.mix_rate = 22050
		var data := PackedByteArray()
		var length := 0.15 + kind * 0.07
		for i in range(int(length * 22050)):
			var t := float(i) / 22050
			var sample := (rng.randf_range(-1, 1) * 0.65 + sin(t * (90 - t * 170) * TAU) * 0.35) * exp(-t * 30)
			var n := int(clampf(sample, -1, 1) * 26000)
			data.append(n & 255)
			data.append((n >> 8) & 255)
		sound.data = data
		streams.append(sound)

func shot(at: Vector3, kind: int) -> void:
	if volume <= 0:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = streams[kind]
	player.volume_db = linear_to_db(volume)
	player.max_distance = 110
	player.unit_size = 9
	add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()
