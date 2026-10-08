extends SceneTree

class RouteHost extends Node:
	var samples := 0
	func android_route_state() -> String:
		samples += 1
		return JSON.stringify({"alive": true, "health": 80})

func _initialize() -> void:
	var host := RouteHost.new()
	var profile = load("res://scripts/mobile_performance.gd").new()
	# Keep the fixture outside the scene tree: exercise the sampling clock
	# without starting rendering or requiring a game world.
	host.add_child(profile)
	assert(is_equal_approx(profile.route_sample_interval,
		0.2 if "--profile-game" in OS.get_cmdline_user_args() else 1.0))
	profile.route_sample_interval = 1.0
	profile.sample_seconds = 2.5
	profile.sample_route_state(0.75)
	assert(host.samples == 0)
	profile.sample_route_state(0.25)
	assert(host.samples == 1)
	profile.sample_route_state(0.5)
	assert(host.samples == 1)
	profile.sample_route_state(8.0)
	assert(host.samples == 2)
	profile.sample_route_state(0.5)
	assert(host.samples == 2)
	profile.sample_route_state(0.5)
	assert(host.samples == 3)
	profile.route_sample_interval = 0.2
	profile.sample_route_state(0.1)
	assert(host.samples == 3)
	profile.sample_route_state(0.1)
	assert(host.samples == 4)
	profile.sample_route_state(8.0)
	assert(host.samples == 5)
	profile.sample_route_state(0.1)
	assert(host.samples == 5)
	profile.sample_route_state(0.1)
	assert(host.samples == 6)
	assert(profile.sample_seconds == 2.5)
	host.free()
	print("MOBILE_ROUTE_TELEMETRY_PASS")
	quit()
