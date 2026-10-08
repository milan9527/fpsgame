extends SceneTree

# CPU-only diagnostic; these timings are not Android presentation intervals.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sound = load("res://scripts/sound.gd").new()
	root.add_child(sound)
	sound.volume = 0
	var camera := Camera3D.new()
	root.add_child(camera)
	var actors := {}
	for id in range(32):
		var actor = load("res://scripts/actor.gd").new()
		actor.velocity = Vector3(3, 0, 0)
		actor.grounded = true
		actors[id] = actor
	for trial in range(6):
		var started := Time.get_ticks_usec()
		for frame in range(2000):
			for id in actors:
				actors[id].position.x += 0.05
			sound.update_actors(actors, null, camera)
		print("AUDIO_UPDATE_CPU trial=%d actors=32 frames=2000 usec=%d" % [trial, Time.get_ticks_usec() - started])
	for id in actors:
		actors[id].free()
	sound.queue_free()
	camera.queue_free()
	await process_frame
	quit()
