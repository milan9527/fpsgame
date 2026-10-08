extends SceneTree

class Member:
	extends RefCounted
	var display_name := "RANGER"
	var position := Vector3.ZERO
	var alive := true
	var downed := false
	var health := 100.0
	var bleed_left := 30.0
	var revive_target := 0
	var revive_left := 5.0

func original_text(member, viewer: Vector3) -> String:
	var state := "%d HP" % ceili(member.health)
	if not member.alive:
		state = "ELIMINATED"
	elif member.downed:
		state = "DOWNED / %.0fs" % member.bleed_left
	elif member.revive_target != 0:
		state = "REVIVING / %.1fs" % member.revive_left
	return "\n%s\n%s  /  %dm" % [member.display_name, state, roundi(viewer.distance_to(member.position))]

func _initialize() -> void:
	var ui = load("res://scripts/interface.gd").new()
	var member := Member.new()
	var cache = ui.TeamMemberTextCache.new()
	var cases := 0
	for alive in [true, false]:
		member.alive = alive
		for downed in [false, true]:
			member.downed = downed
			for revive in [0, 7]:
				member.revive_target = revive
				for value in [-1.1, -0.1, 0.0, 0.049, 0.05, 0.499, 0.5, 0.501, 1.0, 29.95, 99.1, 100.0, 100.1, 150.0]:
					member.health = value
					member.bleed_left = value
					member.revive_left = value
					member.position = Vector3(value, 2, -3)
					for viewer in [Vector3.ZERO, Vector3(5, 1, -7)]:
						assert(ui.team_member_text(member, viewer, cache) == original_text(member, viewer))
						assert(ui.team_member_text(member, viewer, cache) == original_text(member, viewer))
						cases += 1
	# A reused marker slot must follow replacements and in-place name changes.
	member = Member.new()
	member.display_name = "REPLACEMENT"
	assert(ui.team_member_text(member, Vector3.ZERO, cache) == original_text(member, Vector3.ZERO))
	member.display_name = "RENAMED"
	assert(ui.team_member_text(member, Vector3.ZERO, cache) == original_text(member, Vector3.ZERO))
	for scenario in ["stable", "distance", "health"]:
		var count := 100000
		var started := Time.get_ticks_usec()
		for i in count:
			if scenario == "distance":
				member.position.x = float(i % 100)
			elif scenario == "health":
				member.health = float(i % 100)
			original_text(member, Vector3.ZERO)
		var original_us := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for i in count:
			if scenario == "distance":
				member.position.x = float(i % 100)
			elif scenario == "health":
				member.health = float(i % 100)
			ui.team_member_text(member, Vector3.ZERO, cache)
		print("TEAM_TEXT_TIMING scenario=%s count=%d original_us=%d cached_us=%d" % [scenario, count, original_us, Time.get_ticks_usec() - started])
	ui.free()
	print("TEAM_MEMBER_TEXT_PASS cases=%d repeated=ok replacement=ok rename=ok" % cases)
	quit()
