extends SceneTree

# Isolated renderer diagnostic, not an Android performance acceptance test.
const Blast = preload("res://scripts/blast_effect.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output := OS.get_environment("CAPTURE_ARTIFACT_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("A rendered display and CAPTURE_ARTIFACT_DIR are required")
		quit(2)
		return
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.current = true
	var stage := Node3D.new()
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	stage.position = Vector3(0, 1000, 0)
	host.add_child(stage)
	camera.global_position = stage.global_position + Vector3(0, 0, 3)
	camera.look_at(stage.global_position)
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	var samples := []
	var passed := true
	# Isolate each actual resource so smoke cannot mask missing sparks.
	for kind in range(2):
		var particles := Blast.create_particles()
		var particle := particles[kind]
		particles[1 - kind].free()
		particle.process_mode = Node.PROCESS_MODE_ALWAYS
		particle.preprocess = 0.1
		stage.add_child(particle)
		var frames := []
		for frame in range(2):
			await process_frame
			await RenderingServer.frame_post_draw
			frames.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		var image_path := output.path_join(str(particle.name) + ".png")
		var image_error := root.get_texture().get_image().save_png(image_path)
		var drawn: bool = frames.max() > baseline
		passed = passed and drawn and image_error == OK
		samples.append({"particle": str(particle.name), "primitive_counts": frames,
			"drawn_in_warmup_window": drawn, "screenshot": image_path,
			"screenshot_error": image_error})
		particle.queue_free()
		await process_frame
		await RenderingServer.frame_post_draw
	var report := {"diagnostic_only": true, "android_acceptance": false,
		"adapter": RenderingServer.get_video_adapter_name(),
		"baseline_primitives": baseline, "samples": samples, "passed": passed}
	var file := FileAccess.open(output.path_join("draw-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("BLAST_WARMUP_DRAW_", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
