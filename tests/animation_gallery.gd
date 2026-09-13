extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world = load("res://scripts/world.gd").new()
	scene.add_child(world)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 2.0, -21)
	camera.look_at(Vector3(0, 0.95, -15))
	camera.fov = 56
	camera.current = true
	for i in range(3):
		var actor = load("res://scripts/actor.gd").new()
		actor.actor_id = i
		actor.position = Vector3((i - 1) * 2.0, 0.02, -15)
		scene.add_child(actor)
		actor.grounded = true
		if i == 1:
			actor.velocity = Vector3(0, 0, -4.5)
		elif i == 2:
			actor.crouch = true
			actor.update_stance()
		actor.character_animation.update(actor, 0.22)
		actor.update_weapon_attachment()
		var label := Label3D.new()
		label.text = ["IDLE / READY", "WALK / SKINNED", "CROUCH / SKINNED"][i]
		label.position = actor.position + Vector3(0, 2.0 if i < 2 else 1.45, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.pixel_size = 0.0028
		scene.add_child(label)
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("CAPTURE_PATH"))
	print("ANIMATION_GALLERY_RENDERED")
	quit()
