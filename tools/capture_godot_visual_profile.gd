extends SceneTree
## Loopback-only Godot 4 remote visual profiler. Diagnostic CPU stage timestamps,
## NOT Android presentation intervals or acceptance evidence.
## godot --headless --script tools/capture_godot_visual_profile.gd -- output.jsonl [seconds] [port]
var server := TCPServer.new()
var stream: StreamPeerTCP
var packets := PacketPeerStream.new()
var output: FileAccess
var deadline: int
var frames := 0
var profiler_thread = null

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or FileAccess.file_exists(args[0]):
		printerr("Supply a new output JSONL path; existing evidence is never overwritten.")
		quit(2)
		return
	var duration := float(args[1]) if args.size() > 1 else 30.0
	var port := int(args[2]) if args.size() > 2 else 6007
	if duration <= 0 or port < 1 or port > 65535:
		quit(2)
		return
	if server.listen(port, "127.0.0.1") != OK:
		quit(2)
		return
	output = FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		server.stop()
		quit(2)
		return
	packets.set_input_buffer_max_size(8 * 1024 * 1024)
	_record_clock("start")
	deadline = Time.get_ticks_msec() + int(duration * 1000)
	print("VISUAL_PROFILE_LISTENING 127.0.0.1:%d" % port)

func _process(_delta: float) -> bool:
	if output == null:
		return false
	if stream == null and server.is_connection_available():
		stream = server.take_connection()
		packets.stream_peer = stream
	if stream != null:
		stream.poll()
		while packets.get_available_packet_count() > 0:
			var message = packets.get_var(false)
			if packets.get_packet_error() != OK:
				_finish(2)
				return false
			if not message is Array or message.size() != 3:
				continue
			# The engine routes commands to an existing thread ID. Its built-in
			# performance profiler ticks on the main thread, even before visual
			# profiling is enabled.
			if profiler_thread == null and message[0] == "performance:profile_frame":
				profiler_thread = message[1]
				if packets.put_var(["profiler:visual", profiler_thread, [true]]) != OK:
					_finish(2)
					return false
			if message[0] == "visual:profile_frame" or message[0] == "visual:hardware_info":
				output.store_line(JSON.stringify({
					"received_ticks_usec": Time.get_ticks_usec(),
					"message": message[0], "thread_id": message[1],
					"data": message[2],
				}))
				if message[0] == "visual:profile_frame":
					frames += 1
					if frames % 60 == 0:
						output.flush()
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_finish(0 if frames > 0 else 3)
			return false
	if Time.get_ticks_msec() >= deadline:
		_finish(0 if frames > 0 else 3)
	return false

func _record_clock(phase: String) -> void:
	# Host receive-clock anchor only. TCP buffering and host/device clock
	# differences prevent treating this as the Android frame's render time.
	var before := Time.get_ticks_usec()
	var epoch := Time.get_unix_time_from_system()
	var after := Time.get_ticks_usec()
	output.store_line(JSON.stringify({
		"message": "collector:clock", "phase": phase,
		"host_ticks_before_usec": before, "host_epoch_seconds": epoch,
		"host_ticks_after_usec": after,
	}))
	output.flush()

func _finish(code: int) -> void:
	if profiler_thread != null and stream != null and stream.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		packets.put_var(["profiler:visual", profiler_thread, [false]])
	_record_clock("finish")
	output.flush()
	output.close()
	output = null
	server.stop()
	print("VISUAL_PROFILE_FRAMES %d" % frames)
	quit(code)
