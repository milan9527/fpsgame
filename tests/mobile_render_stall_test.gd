extends SceneTree

class Host extends Node:
	var world := Node3D.new()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var host := Host.new()
	root.add_child(host)
	host.add_child(host.world)
	var camera := Camera3D.new()
	host.world.add_child(camera)
	camera.position = Vector3(12, 3, -7)
	camera.current = true
	var controller = load("res://scripts/mobile_performance.gd").new()
	host.add_child(controller)
	controller.set_process(false)
	controller.record_render_stall(50.0, 1000)
	assert(controller.render_stalls.is_empty())
	controller.render_started_usec = 123
	var drawn_before := Engine.get_frames_drawn()
	var processed_before := Engine.get_process_frames()
	for i in range(10):
		controller.record_render_stall(51.0 + i, 2000 + i)
	assert(controller.render_stalls.size() == 8)
	assert(controller.render_stalls_omitted == 2)
	var sample: Dictionary = controller.render_stalls[0]
	assert(sample.end_ticks_usec == 2000)
	assert(sample.begin_ticks_usec == 123)
	assert(sample.engine_frames_drawn == drawn_before)
	assert(sample.engine_process_frames == processed_before)
	assert(sample.render_wall_ms == 51.0)
	assert(sample.blast.created_count == 0)
	var blast = load("res://scripts/blast_effect.gd").new()
	host.world.add_child(blast)
	assert(sample.blast.created_count == 0)
	assert(sample.camera_position == [12.0, 3.0, -7.0])
	assert(sample.camera_forward == [0.0, 0.0, -1.0])
	assert(JSON.parse_string(JSON.stringify(sample)) is Dictionary)
	controller.flush_render_stalls()
	assert(controller.render_stalls.is_empty())
	assert(controller.render_stalls_omitted == 0)
	controller.record_render_stall(52.0, Time.get_ticks_usec())
	var with_blast: Dictionary = controller.render_stalls[0]
	assert(with_blast.blast.created_count == 1)
	assert(with_blast.blast.active_count == 1)
	assert(with_blast.blast.last_ready_end_usec <= with_blast.end_ticks_usec)
	controller.flush_render_stalls()
	host.free()
	print("MOBILE_RENDER_STALL_TEST PASS (synthetic unit fixture, not frame evidence)")
	quit()
