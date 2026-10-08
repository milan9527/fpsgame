extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scripts/game.gd").new()
	root.add_child(game)
	game.local_profile = null
	await process_frame
	game.start_solo()
	game.set_physics_process(false)
	game.set_process(false)
	var actor = game.actors[game.local_id]
	var at := Vector3(49,0.05,40)
	var target := Vector3(46,2.1,31)
	actor.position = at
	var delta := at + Vector3(0,1.6,0) - target
	actor.yaw = atan2(delta.x,delta.z)
	actor.pitch = -atan2(delta.y,Vector2(delta.x,delta.z).length())
	for frame in range(60): actor.render_frame(1.0/60.0,false,true,false)
	game.ui.update_hud(actor,16,"live",300,110,[],"")
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var out := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	assert(root.get_texture().get_image().save_png(out.path_join("water-service.png")) == OK)
	var file := FileAccess.open(out.path_join("water-camera-poses.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"actor_position":[49,0.05,40],"target":[46,2.1,31],"yaw_radians":actor.yaw,"pitch_radians":actor.pitch,"eye_offset_y":1.6,"viewport":[1280,800]},"\t"))
	file.close()
	print("WATER_CAPTURE_PASS")
	quit()
