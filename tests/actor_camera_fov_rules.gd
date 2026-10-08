extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := preload("res://scripts/actor.gd").new()
	root.add_child(actor)
	var reference := Camera3D.new()
	root.add_child(reference)
	reference.fov = actor.camera.fov
	reference.near = actor.camera.near
	reference.far = actor.camera.far
	var unchanged := 0
	for i in range(6000):
		actor.weapon = (i / 1000) % 3
		var aiming := i % 1000 >= 400
		var dt := [0.0, 1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0][i % 4] as float
		if i % 997 == 0:
			dt = 0.12
		var before: float = actor.camera.fov
		reference.fov = lerpf(reference.fov, actor.AIM_FOV[actor.weapon] if aiming else 85.0, minf(1, dt * 12))
		actor.update_camera_fov(dt, aiming)
		assert(actor.camera.fov == reference.fov, "ADS interpolation changed")
		assert(actor.camera.get_camera_projection() == reference.get_camera_projection(), "Camera projection changed")
		if before == actor.camera.fov:
			unchanged += 1
	assert(unchanged > 1200)
	print("ACTOR_CAMERA_FOV_PASS samples=6000 exact_projection=true unchanged=%d" % unchanged)
	actor.queue_free()
	reference.queue_free()
	await process_frame
	quit()
