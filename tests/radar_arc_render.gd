extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cache = preload("res://scripts/radar_arc.gd").new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Node2D.new()
	viewport.add_child(canvas)
	# Repeated geometry, resize/move and shrinking circles, both HUD widths.
	for sample in [
		[Vector2(160, 160), 79.2, 2.0],
		[Vector2(160, 160), 79.2, 2.0],
		[Vector2(140.25, 145.5), 37.44, 1.0],
		[Vector2(140.25, 145.5), 36.72, 2.0],
		[Vector2(200, 120), 0.0, 1.0],
	]:
		var native = func(): canvas.draw_arc(sample[0], sample[1], 0, TAU, 64, Color.WHITE, sample[2])
		canvas.draw.connect(native)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var expected := viewport.get_texture().get_image()
		if sample[1] > 0:
			assert(not expected.is_invisible(), "Native arc must render visible pixels")
		canvas.draw.disconnect(native)
		var cached = func(): canvas.draw_polyline(cache.points(sample[0], sample[1]), Color.WHITE, sample[2])
		canvas.draw.connect(cached)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		assert(expected.get_data() == actual.get_data(), "Cached radar arc changed rendered pixels: %s" % str(sample))
		canvas.draw.disconnect(cached)
	print("RADAR_ARC_RENDER_PASS samples=5 native_pixels=identical")
	quit()
