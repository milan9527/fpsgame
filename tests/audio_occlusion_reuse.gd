extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 3, 3)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(2, 0, 0)
	var sound = load("res://scripts/sound.gd").new()
	world.add_child(sound)
	await physics_frame
	await physics_frame
	var blocked = sound.effect("gun_ar", Vector3(4, 0, 0))
	assert(blocked != null)
	assert(is_equal_approx(float(blocked.get_meta("gain")), db_to_linear(-9)))
	assert(is_equal_approx(blocked.attenuation_filter_cutoff_hz, 1500.0))
	var open = sound.effect("gun_ar", Vector3(0, 0, 4))
	assert(is_equal_approx(float(open.get_meta("gain")), 1.0))
	# Same source, moved listener: a stale origin would still hit the wall.
	sound.listener.global_position = Vector3(4, 0, 4)
	var moved = sound.effect("gun_ar", Vector3(4, 0, 0))
	assert(is_equal_approx(float(moved.get_meta("gain")), 1.0))
	sound.listener.global_position = Vector3.ZERO
	var blocked_again = sound.effect("gun_ar", Vector3(4, 0, 0))
	assert(is_equal_approx(float(blocked_again.get_meta("gain")), db_to_linear(-9)))
	var ui = sound.effect("hit", Vector3(4, 0, 0), false, 0.55)
	assert(ui is AudioStreamPlayer)
	assert(is_equal_approx(float(ui.get_meta("gain")), 0.55))
	# Other collision layers retain the original mask=1 behavior.
	wall.collision_layer = 2
	await physics_frame
	await physics_frame
	var other_layer = sound.effect("gun_ar", Vector3(4, 0, 0))
	assert(is_equal_approx(float(other_layer.get_meta("gain")), 1.0))
	world.queue_free()
	await process_frame
	# Let the audio thread retire stopped playback before terminating the test.
	await create_timer(0.25).timeout
	print("PASS audio occlusion: blocked/open, moving endpoints, UI, collision mask")
	quit()
