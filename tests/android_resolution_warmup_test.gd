extends SceneTree

class WorldHost extends Node3D:
	var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host := WorldHost.new()
	host.world = Node3D.new()
	host.add_child(host.world)
	root.add_child(host)
	var profile = load("res://scripts/mobile_performance.gd").new()
	host.add_child(profile)
	profile.set_process(false)
	root.scaling_3d_scale = 0.65
	# A pre-existing partial window must not bleed across loading.
	profile.adapt_resolution(0.5)
	profile.resolution_recovery_seconds = 6.0
	profile.last_frame_usec = 123456
	profile.frame_times.append(11113.824)
	profile.set_resolution_warmup(true)
	# Representative r661 startup stalls; no framebuffer resizes during warmup.
	for elapsed in [11.113824, 0.125601, 0.592385, 2.835855, 0.563021, 2.014651]:
		profile.adapt_resolution(elapsed)
	assert(is_equal_approx(root.scaling_3d_scale, 0.65))
	assert(profile.resolution_sample_count == 0)
	assert(profile.resolution_recovery_seconds == 0.0)
	profile.set_resolution_warmup(false)
	profile.adapt_resolution(2.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.65))
	assert(profile.resolution_sample_count == 0)
	# Diagnostics and their clock are never reset or filtered by this gate.
	assert(profile.last_frame_usec == 123456)
	assert(profile.frame_times == [11113.824])
	# Genuine sustained gameplay pressure still lowers resolution.
	for index in range(101):
		profile.adapt_resolution(0.02)
	assert(is_equal_approx(root.scaling_3d_scale, 0.60))
	# Recovery still requires eight seconds of near-60 FPS headroom.
	for index in range(360):
		profile.adapt_resolution(1.0 / 60.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.60))
	for index in range(130):
		profile.adapt_resolution(1.0 / 60.0)
	assert(is_equal_approx(root.scaling_3d_scale, 0.65))
	print("RESOLUTION_WARMUP_PASS loading gate, transition, diagnostic preservation, sustained load and recovery")
	host.free()
	quit()
