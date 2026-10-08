extends SceneTree

const Bindings = preload("res://scripts/control_bindings.gd")
const Interface = preload("res://scripts/interface.gd")

func _initialize() -> void:
	var bindings = Bindings.new()
	bindings.apply()
	var ui = Interface.new()
	var actor := {"magazines": [30, 8, 5], "medkits": 2, "grenades": 3, "smokes": 1}
	assert(ui.foot_loadout_text(actor) == "1  AR 30   |   2  SG 08   |   3  SR 05")
	assert(ui.foot_supply_text(actor) == "H  Medkit ×2   |   G  Frag ×3   |   V  Smoke ×1")
	for frame in range(120):
		assert(ui.foot_loadout_text(actor) == "1  AR 30   |   2  SG 08   |   3  SR 05")
		assert(ui.foot_supply_text(actor) == "H  Medkit ×2   |   G  Frag ×3   |   V  Smoke ×1")
	actor.magazines[1] = 0
	actor.medkits = 0
	actor.grenades = 1
	actor.smokes = 0
	assert(ui.foot_loadout_text(actor) == "1  AR 30   |   2  SG 00   |   3  SR 05")
	assert(ui.foot_supply_text(actor) == "H  Medkit ×0   |   G  Frag ×1   |   V  Smoke ×0")
	# Applying controls in memory must invalidate text even with identical counts.
	# No profile files are written by this test.
	bindings.keys.weapon1 = KEY_4
	bindings.keys.heal = KEY_J
	bindings.apply()
	assert(ui.foot_loadout_text(actor).begins_with("4  AR 30"))
	assert(ui.foot_supply_text(actor).begins_with("J  Medkit ×0"))
	var other := {"magazines": [7, 6, 99], "medkits": 4, "grenades": 0, "smokes": 2}
	assert(ui.foot_loadout_text(other) == "4  AR 07   |   2  SG 06   |   3  SR 99")
	assert(ui.foot_supply_text(other) == "J  Medkit ×4   |   G  Frag ×0   |   V  Smoke ×2")
	bindings.keys = Bindings.DEFAULTS.duplicate()
	bindings.apply()
	assert(ui.foot_loadout_text(other).begins_with("1  AR 07"))
	assert(ui.foot_supply_text(other).begins_with("H  Medkit ×4"))
	ui.free()
	print("HUD_INVENTORY_TEXT_PASS consumption=ok actor_switch=ok rebind=ok defaults=ok")
	quit()
