extends SceneTree

class Actor:
	extends RefCounted
	const NAMES := ["AR", "SG", "SR"]
	var weapon := 0
	var ammo := 30
	var reserve := 120
	var crouched := false
	var lean := 0.0

func original_text(actor) -> String:
	var text := "%s    %02d / %03d" % [actor.NAMES[actor.weapon], actor.ammo, actor.reserve]
	if actor.crouched:
		text += "  [CROUCHED]"
	if absf(actor.lean) > 0.05:
		text += "  [LEAN L]" if actor.lean < 0 else "  [LEAN R]"
	return text

func _initialize() -> void:
	var ui = load("res://scripts/interface.gd").new()
	var actor := Actor.new()
	var checked := 0
	for weapon in range(3):
		actor.weapon = weapon
		for ammo in [0, 1, 30]:
			actor.ammo = ammo
			for reserve in [0, 120]:
				actor.reserve = reserve
				for crouched in [false, true]:
					actor.crouched = crouched
					for lean in [-1.0, -0.051, -0.05, 0.0, 0.05, 0.051, 1.0]:
						actor.lean = lean
						assert(ui.foot_weapon_text(actor) == original_text(actor))
						assert(ui.foot_weapon_text(actor) == original_text(actor))
						checked += 1
	var other := Actor.new()
	assert(ui.foot_weapon_text(other) == original_text(other))
	assert(ui.foot_weapon_text(actor) == original_text(actor))
	# Measure both steady and changing ammunition. Desktop CPU timing only.
	for changing in [false, true]:
		var count := 100000
		var started := Time.get_ticks_usec()
		for i in range(count):
			if changing:
				actor.ammo = i % 31
			original_text(actor)
		var original_us := Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
		for i in range(count):
			if changing:
				actor.ammo = i % 31
			ui.foot_weapon_text(actor)
		var cached_us := Time.get_ticks_usec() - started
		print("HUD_TEXT_TIMING changing=%s count=%d original_us=%d cached_us=%d" % [changing, count, original_us, cached_us])
	ui.free()
	print("HUD_WEAPON_TEXT_PASS cases=%d actor_switch=ok" % checked)
	quit()
