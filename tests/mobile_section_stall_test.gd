extends SceneTree

func _initialize() -> void:
	var game = load("res://scripts/game.gd").new()
	game.android_profile_enabled = false
	game.record_slow_section("disabled", 80.0, 1000)
	assert(game.android_slow_sections.is_empty())
	game.record_profile_section("disabled", Time.get_ticks_usec())
	assert(game.android_section_totals.is_empty())
	game.android_profile_enabled = true
	# Explicit timestamps make section totals and slow-event duration agree,
	# independent of the time spent inside the diagnostic accumulator.
	game.record_profile_section("timestamped", 1000, 52500)
	game.record_profile_section("timestamped", 52500, 53500)
	var timestamped: Array = game.android_section_totals["timestamped"]
	assert(timestamped == [52.5, 2, 51.5])
	assert(game.android_slow_sections.size() == 1)
	assert(game.android_slow_sections[0].section == "timestamped")
	assert(game.android_slow_sections[0].ms == 51.5)
	assert(game.android_slow_sections[0].end_ticks_usec == 52500)
	game.android_slow_sections.clear()
	game.record_profile_section("actors", Time.get_ticks_usec() - 2000)
	var accumulator: Array = game.android_section_totals["actors"]
	assert(accumulator[1] == 1)
	assert(accumulator[0] >= 2.0)
	var first_total: float = accumulator[0]
	game.record_profile_section("actors", Time.get_ticks_usec() - 3000)
	assert(accumulator[1] == 2)
	assert(accumulator[0] >= first_total + 3.0)
	assert(accumulator[2] >= 3.0)
	game.record_profile_section("network", Time.get_ticks_usec())
	assert(game.android_section_totals["network"][1] == 1)
	assert(accumulator[1] == 2)
	game.record_slow_section("fast", 49.9, 1000)
	assert(game.android_slow_sections.is_empty())
	for i in range(10):
		game.record_slow_section("actors", 50.0 + i, 2000 + i)
	assert(game.android_slow_sections.size() == 8)
	assert(game.android_slow_sections_omitted == 2)
	assert(game.android_slow_sections[0].ms == 50.0)
	assert(game.android_slow_sections[0].end_ticks_usec == 2000)
	game.android_profile_due = Time.get_ticks_msec() + 10000
	game.flush_profile_sections()
	assert(game.android_slow_sections.size() == 8)
	game.android_profile_due = 0
	game.flush_profile_sections()
	assert(game.android_slow_sections.is_empty())
	assert(game.android_slow_sections_omitted == 0)
	assert(game.android_section_totals.is_empty())
	game.record_profile_section("actors", Time.get_ticks_usec())
	assert(game.android_section_totals["actors"][1] == 1)
	assert(accumulator[1] == 2)
	# An idle/early-return physics tick is still counted, with its own clock.
	game.running = false
	var marker_before: int = game.android_section_started
	game._physics_process(1.0 / 60.0)
	assert(game.android_section_totals["physics_tick"][1] == 1)
	assert(game.android_section_started == marker_before)
	game.free()
	print("MOBILE_SECTION_STALL_TEST PASS (synthetic diagnostic test, not frame evidence)")
	quit()
